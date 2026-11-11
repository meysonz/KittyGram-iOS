import Foundation
import Postbox
import SwiftSignalKit

/// "Save Deleted Messages" keeps a message, but a photo or video survives only if its file was downloaded before the
/// deletion, and Telegram downloads media only when the chat is on screen. So incoming photos, videos, voice and video
/// messages of private chats (not bots) are downloaded as soon as they arrive. Files over 50 MB are skipped.
public func kittyGramPrefetchPrivateChatMedia(account: Account, messages: [Message]) {
    let settings = KittyGramSettings.shared
    if !settings.saveDeleted {
        return
    }
    let maxFileSize: Int64 = 50 * 1024 * 1024
    for message in messages {
        guard message.id.peerId.namespace == Namespaces.Peer.CloudUser, message.id.namespace == Namespaces.Message.Cloud, message.flags.contains(.Incoming) else {
            continue
        }
        if let user = message.peers[message.id.peerId] as? TelegramUser, user.botInfo != nil {
            continue
        }
        let messageReference = MessageReference(message)
        for media in message.media {
            if let image = media as? TelegramMediaImage, let representation = largestImageRepresentation(image.representations) {
                let _ = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .peer(message.id.peerId), userContentType: .image, reference: .media(media: .message(message: messageReference, media: image), resource: representation.resource), continueInBackground: true).start()
            } else if let file = media as? TelegramMediaFile {
                if !(file.isVideo || file.isVoice || file.isInstantVideo || file.isAnimated) {
                    continue
                }
                if let size = file.size, size > maxFileSize {
                    continue
                }
                let contentType: MediaResourceUserContentType
                if file.isInstantVideo {
                    contentType = .audioVideoMessage
                } else if file.isVoice {
                    contentType = .audio
                } else {
                    contentType = .video
                }
                let _ = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .peer(message.id.peerId), userContentType: contentType, reference: .media(media: .message(message: messageReference, media: file), resource: file.resource), continueInBackground: true).start()
            }
        }
    }
}
