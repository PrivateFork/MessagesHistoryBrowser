//
//  MessagesListViewController.swift
//  MessagesHistoryBrowser
//
//  Created by Guillaume Laurent on 04/10/15.
//  Copyright © 2015 Guillaume Laurent. All rights reserved.
//

import Cocoa

class MessagesListViewController: NSViewController, NSCollectionViewDataSource, AttachmentsCollectionViewDelegate {

    let collectionViewItemID = "AttachmentsCollectionViewItem"

    let windowControllerId = "ImageAttachmentDisplayWindowController"

    @IBOutlet weak var attachmentsCollectionView: NSCollectionView!
    @IBOutlet var messagesTextView: NSTextView!

    var attachmentsToDisplay:[ChatAttachment]?

    let dateFormatter = DateFormatter()

    let messageFormatter = MessageFormatter()

    // if two messages are seperated by a time interval longer than this, add a time tag in between
    //
    let delayBetweenChatsInSeconds = TimeInterval(24 * 3600)
    
    var terseTimeMode = true {
        didSet {
            messageFormatter.terseTimeMode = terseTimeMode
        }
    }

    var detailedSender = false {
        didSet {
            messageFormatter.detailedSender = detailedSender
        }
    }

    var currentImageAttachmentDisplayWindowController:NSWindowController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do view setup here.

        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .short

        let aNib = NSNib(nibNamed: NSNib.Name(rawValue: collectionViewItemID), bundle: nil)

        attachmentsCollectionView.register(aNib, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: collectionViewItemID))

//        let gridLayout = NSCollectionViewGridLayout()
//        gridLayout.minimumItemSize = NSSize(width: 100, height: 100)
//        gridLayout.maximumItemSize = NSSize(width: 175, height: 175)
//        gridLayout.minimumInteritemSpacing = 10
//        gridLayout.margins = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
//        attachmentsCollectionView.collectionViewLayout = gridLayout

        if let flowLayout = attachmentsCollectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
            flowLayout.minimumInteritemSpacing = 15.0
        }

//        terseTimeMode = false

    }


    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int
    {
        guard let attachmentsToDisplay = attachmentsToDisplay else {
            return 0
        }

        return attachmentsToDisplay.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem
    {
        let attachmentsToDisplay = self.attachmentsToDisplay!

        let attachment = attachmentsToDisplay[indexPath.item]

        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: collectionViewItemID), for: indexPath)

        if let attachmentFileName = attachment.fileName {

            let imagePath = NSString(string:attachmentFileName).standardizingPath
            let image = NSImage(byReferencingFile: imagePath)
            item.imageView?.image = image
            item.textField?.stringValue = dateFormatter.string(from: attachment.date as Date)
        } else {
            item.textField?.stringValue = "unknown"
        }

        return item
    }


    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>)
    {
        NSLog("didSelectItemsAtIndexPaths \(indexPaths)")

        if let attachment = attachmentsToDisplay?[indexPaths.first!.item] {
            if let range = attachment.associatedRange {
                messagesTextView.scrollRangeToVisible(range)
            }
        }

    }

    // MARK: attachments display

    func displayAttachmentAtIndexPath(_ indexPath: IndexPath) {
        NSLog("displayAttachmentAtIndexPath \(indexPath)")

        if currentImageAttachmentDisplayWindowController == nil {
            currentImageAttachmentDisplayWindowController = self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: self.windowControllerId)) as? NSWindowController
        }

        let imageAttachmentDisplayViewController = currentImageAttachmentDisplayWindowController?.contentViewController as! ImageAttachmentDisplayViewController

        if let image = imageForAttachmentAtIndexPath(indexPath) {

            imageAttachmentDisplayViewController.image = image

//            currentImageAttachmentDisplayWindowController.window?.level = Int(CGWindowLevelKey.FloatingWindowLevelKey.rawValue)
            currentImageAttachmentDisplayWindowController?.showWindow(self)
            view.window?.makeKey()

        }

    }

    func hideAttachmentDisplayWindow()
    {
        currentImageAttachmentDisplayWindowController?.window?.orderOut(self)
    }

    func showAttachmentInFinderAtIndexPath(_ indexPath:IndexPath) -> Void
    {
        if let attachment = attachmentsToDisplay?[indexPath.item], let attachmentFileName = attachment.fileName {

            let imagePath = NSString(string:attachmentFileName).standardizingPath
            let imageURL = URL(fileURLWithPath: imagePath)
            NSWorkspace.shared.activateFileViewerSelecting([imageURL])
        }
    }

    func imageForAttachmentAtIndexPath(_ indexPath:IndexPath) -> NSImage?
    {
        if let attachment = attachmentsToDisplay?[indexPath.item], let attachmentFileName = attachment.fileName {

            let imagePath = NSString(string:attachmentFileName).standardizingPath
            let image = NSImage(byReferencingFile: imagePath)
            return image
        }

        return nil
    }

    func clearAttachments()
    {
        attachmentsToDisplay = nil
        attachmentsCollectionView.reloadData()
    }

    // MARK: messages

    func clearMessages()
    {
        messagesTextView.string = ""
    }
    
    func showMessages(_ chatItems:[ChatItem], withHighlightTerm highlightTerm:String? = nil)
    {
        let allMatchingMessages = NSMutableAttributedString()

        var lastShownDate:Date?
        var lastShownContact:ChatContact?
        var lastShownMessageIndex:Int64?


        for chatItem in chatItems {

            if terseTimeMode {
                if lastShownDate == nil || chatItem.date.timeIntervalSince(lastShownDate!) > delayBetweenChatsInSeconds {
                    let highlightedDate = messageFormatter.formatMessageDate(chatItem.date)
                    allMatchingMessages.append(highlightedDate)
                    lastShownMessageIndex = nil
                }
                
                lastShownDate = chatItem.date as Date
            }

            // chatItem can be message or attachment
            // process accordingly
            //
            if let message = chatItem as? ChatMessage {

                guard let highlightedMessage = messageFormatter.formatMessage(message, withHighlightTerm: highlightTerm) else { continue }

                if lastShownContact == nil || lastShownContact!.name != message.contact.name {
                    let highlightedContact = messageFormatter.formatMessageContact(message.contact)
                    allMatchingMessages.append(highlightedContact)
                    lastShownContact = message.contact
                    lastShownMessageIndex = nil
                }

                // insert seperator for non-consecutive messages
                //
                if highlightTerm != nil && lastShownMessageIndex != nil && message.index != (lastShownMessageIndex! + 1) {
                    allMatchingMessages.append(messageFormatter.separatorString)
                }

                lastShownMessageIndex = message.index

                allMatchingMessages.append(highlightedMessage)

            } else {
                let attachment = chatItem as! ChatAttachment

                guard let attachmentFileName = attachment.fileName else { continue }

                let attachmentPath = NSString(string:attachmentFileName).standardizingPath

                let attachmentURL = URL(fileURLWithPath: attachmentPath, isDirectory: false)

                do {
                    let textAttachment:NSTextAttachment

                    if isAttachmentImage(attachment) {

                        textAttachment = NSTextAttachment()
                        let image = NSImage(byReferencingFile: attachmentPath)
                        let textAttachmentCell = ImageAttachmentCell(imageCell: image)
                        textAttachment.attachmentCell = textAttachmentCell

                        let associatedRange = NSRange(location: allMatchingMessages.length, length: 1)
                        attachment.associatedRange = associatedRange

                    } else {

                        let attachmentFileWrapper = try FileWrapper(url: attachmentURL, options:FileWrapper.ReadingOptions(rawValue: 0))
                        textAttachment = NSTextAttachment(fileWrapper: attachmentFileWrapper)

                    }

                    let attachmentString = NSAttributedString(attachment: textAttachment)

                    let attachmentStringWithNewLine = NSMutableAttributedString(attributedString: attachmentString)

                    attachmentStringWithNewLine.append(NSAttributedString(string: "\n"))

                    allMatchingMessages.append(attachmentStringWithNewLine)

                } catch {
                    NSLog("Couldn't create filewrapper for \(String(describing: attachment.fileName))")
                }
            }
        }

        clearMessages()
        messagesTextView.textStorage?.insert(allMatchingMessages, at: 0)

    }

    func isAttachmentImage(_ attachment:ChatAttachment) -> Bool
    {
        guard let attachmentFileName = attachment.fileName else { return false }

        let pathString = NSString(string:attachmentFileName)

        let pathExtension = pathString.pathExtension

        if let utType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue() {

            return UTTypeConformsTo(utType, kUTTypeImage)
        }

        return false
    }

}
