import Foundation
import Postbox

/// "Send without Sound": marks outgoing messages as silent when the setting asks for it.
func kittyGramApplySilentSending(_ messages: [EnqueueMessage]) -> [EnqueueMessage] {
    let settings = KittyGramSettings.shared
    let mode = settings.sendWithoutSound
    let silent = mode == 2 || (mode == 1 && settings.activeGhostFlagCount > 0)
    if !silent {
        return messages
    }
    return messages.map { message -> EnqueueMessage in
        switch message {
        case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            if attributes.contains(where: { $0 is NotificationInfoMessageAttribute }) {
                return message
            }
            var updatedAttributes = attributes
            updatedAttributes.append(NotificationInfoMessageAttribute(flags: .muted))
            return .message(text: text, attributes: updatedAttributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case .forward:
            return message
        }
    }
}
