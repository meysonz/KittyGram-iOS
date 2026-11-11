import Foundation
import Postbox
import SwiftSignalKit

/// Kept deleted messages and (with "Keep Self-Destructing Media") timer / view-once media: the server refuses to forward timer / view-once media, so a forward of such a
/// message is sent as a new message with a copy of the already downloaded file (no timer, no "forwarded from").
/// Media that is not on the device yet stays a normal forward.
func kittyGramCopySelfDestructForwards(postbox: Postbox, messages: [EnqueueMessage]) -> Signal<[EnqueueMessage], NoError> {
    let hasCandidates = messages.contains(where: { message in
        switch message {
        case .forward:
            return true
        case let .message(_, _, _, _, _, replyToMessageId, _, _, _, _):
            return replyToMessageId != nil
        }
    })
    if !hasCandidates {
        return .single(messages)
    }
    return postbox.transaction { transaction -> [EnqueueMessage] in
        return messages.map { message -> EnqueueMessage in
            if case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message {
                // A reply to a kept deleted message: the server drops the reply, so quote the deleted message instead.
                guard let replyToMessageId, let target = transaction.getMessage(replyToMessageId.messageId), target.kittyGramIsDeleted else {
                    return message
                }
                let (quotedText, quotedAttributes) = kittyGramQuoteDeletedMessage(target, text: text, attributes: attributes)
                return .message(text: quotedText, attributes: quotedAttributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: nil, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
            }
            guard case let .forward(source, threadId, _, _, correlationId) = message else {
                return message
            }
            // Kept deleted messages no longer exist on the server, so they too are sent as a copy.
            guard source.peerId.namespace != Namespaces.Peer.SecretChat, let sourceMessage = transaction.getMessage(source), (KittyGramSettings.shared.keepSelfDestructing && sourceMessage.kittyGramIsSelfDestructingMedia) || sourceMessage.kittyGramIsDeleted else {
                return message
            }
            var copiedAttributes: [MessageAttribute] = []
            if let entities = sourceMessage.textEntitiesAttribute {
                copiedAttributes.append(TextEntitiesMessageAttribute(entities: entities.entities))
            }
            let copyableMedia = sourceMessage.media.filter { !($0 is TelegramMediaWebpage) }
            if copyableMedia.isEmpty {
                if sourceMessage.text.isEmpty {
                    return message
                }
                return .message(text: sourceMessage.text, attributes: copiedAttributes, inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: correlationId, bubbleUpEmojiOrStickersets: [])
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
            return .message(text: sourceMessage.text, attributes: copiedAttributes, inlineStickers: [:], mediaReference: .standalone(media: media), threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: correlationId, bubbleUpEmojiOrStickersets: [])
        }
    }
}


/// Puts a quote of the deleted message at the top of the reply: the author's @username (their name when they have
/// none) in bold, then the deleted text (or a short label for media). The reply's own formatting moves down with it.
private func kittyGramQuoteDeletedMessage(_ target: Message, text: String, attributes: [MessageAttribute]) -> (String, [MessageAttribute]) {
    var author = ""
    if let peer = target.author {
        if let addressName = peer.addressName, !addressName.isEmpty {
            author = "@" + addressName
        } else {
            author = peer.debugDisplayTitle
        }
    }
    var quoted = target.text
    if quoted.isEmpty {
        quoted = kittyGramMediaLabel(target.media)
    }
    if quoted.count > 300 {
        quoted = String(quoted.prefix(300)) + "…"
    }
    let quoteBody = author.isEmpty ? quoted : author + "\n" + quoted
    let prefix = quoteBody + "\n"
    let quoteLength = (quoteBody as NSString).length
    let shift = (prefix as NSString).length

    var entities: [MessageTextEntity] = [MessageTextEntity(range: 0 ..< quoteLength, type: .BlockQuote(isCollapsed: false))]
    if !author.isEmpty {
        entities.append(MessageTextEntity(range: 0 ..< (author as NSString).length, type: .Bold))
    }
    var updatedAttributes: [MessageAttribute] = []
    for attribute in attributes {
        if let textEntities = attribute as? TextEntitiesMessageAttribute {
            for entity in textEntities.entities {
                entities.append(MessageTextEntity(range: (entity.range.lowerBound + shift) ..< (entity.range.upperBound + shift), type: entity.type))
            }
        } else {
            updatedAttributes.append(attribute)
        }
    }
    updatedAttributes.append(TextEntitiesMessageAttribute(entities: entities))
    return (prefix + text, updatedAttributes)
}

private func kittyGramMediaLabel(_ media: [Media]) -> String {
    for item in media {
        if item is TelegramMediaImage {
            return "📷 Фото"
        }
        if let file = item as? TelegramMediaFile {
            if file.isInstantVideo {
                return "⏺ Кружок"
            } else if file.isVoice {
                return "🎤 Голосовое"
            } else if file.isSticker || file.isAnimatedSticker {
                return "Стикер"
            } else if file.isAnimated {
                return "GIF"
            } else if file.isVideo {
                return "🎥 Видео"
            } else {
                return "📎 Файл"
            }
        }
    }
    return "Сообщение"
}
