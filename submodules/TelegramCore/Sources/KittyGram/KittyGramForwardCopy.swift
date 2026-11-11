import Foundation
import Postbox
import SwiftSignalKit

/// "Keep Self-Destructing Media": the server refuses to forward timer / view-once media, so a forward of such a
/// message is sent as a new message with a copy of the already downloaded file (no timer, no "forwarded from").
/// Media that is not on the device yet stays a normal forward.
func kittyGramCopySelfDestructForwards(postbox: Postbox, messages: [EnqueueMessage]) -> Signal<[EnqueueMessage], NoError> {
    if !KittyGramSettings.shared.keepSelfDestructing {
        return .single(messages)
    }
    if !messages.contains(where: { if case .forward = $0 { return true } else { return false } }) {
        return .single(messages)
    }
    return postbox.transaction { transaction -> [EnqueueMessage] in
        return messages.map { message -> EnqueueMessage in
            guard case let .forward(source, threadId, _, _, correlationId) = message else {
                return message
            }
            guard source.peerId.namespace != Namespaces.Peer.SecretChat, let sourceMessage = transaction.getMessage(source), sourceMessage.kittyGramIsSelfDestructingMedia else {
                return message
            }
            var copiedMedia: Media?
            for media in sourceMessage.media {
                if let image = media as? TelegramMediaImage, let representation = largestImageRepresentation(image.representations) {
                    guard postbox.mediaBox.completedResourcePath(representation.resource) != nil else {
                        continue
                    }
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: representation.resource.size)
                    postbox.mediaBox.copyResourceData(from: representation.resource.id, to: resource.id, synchronous: true)
                    copiedMedia = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: [TelegramMediaImageRepresentation(dimensions: representation.dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)], immediateThumbnailData: image.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                    break
                } else if let file = media as? TelegramMediaFile {
                    guard postbox.mediaBox.completedResourcePath(file.resource) != nil else {
                        continue
                    }
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: file.size)
                    postbox.mediaBox.copyResourceData(from: file.resource.id, to: resource.id, synchronous: true)
                    copiedMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: file.immediateThumbnailData, mimeType: file.mimeType, size: file.size, attributes: file.attributes, alternativeRepresentations: [])
                    break
                }
            }
            guard let media = copiedMedia else {
                return message
            }
            return .message(text: sourceMessage.text, attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: correlationId, bubbleUpEmojiOrStickersets: [])
        }
    }
}
