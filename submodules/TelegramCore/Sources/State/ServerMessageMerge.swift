import Foundation
import Postbox

/// The server's copy of a message the account already stores, keeping what the server's copy does not carry:
/// the outgoing live-location tag, the stored Incoming flag, a translation while the text and entities are
/// unchanged, a resolved fact check over a pending one with the same hash, and unlocked paid media.
/// (`SeedConfiguration.mergeMessageAttributes`, which Postbox applies to every update, keeps the rest.)
/// Used by edit updates and by feed pages, which refresh posts the account may already store.
func mergedServerMessageUpdate(previous previousMessage: Message, updated message: StoreMessage) -> StoreMessage {
    var updatedFlags = message.flags
    var updatedLocalTags = message.localTags
    var updatedAttributes = message.attributes
    if previousMessage.localTags.contains(.OutgoingLiveLocation) {
        updatedLocalTags.insert(.OutgoingLiveLocation)
    }
    if previousMessage.flags.contains(.Incoming) {
        updatedFlags.insert(.Incoming)
    } else {
        updatedFlags.remove(.Incoming)
    }

    if previousMessage.text == message.text {
        let previousEntities = previousMessage.textEntitiesAttribute?.entities ?? []
        let updatedEntities = (message.attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute)?.entities ?? []
        if previousEntities == updatedEntities, let translation = previousMessage.attributes.first(where: { $0 is TranslationMessageAttribute }) as? TranslationMessageAttribute {
            if message.attributes.firstIndex(where: { $0 is TranslationMessageAttribute }) == nil {
                updatedAttributes.append(translation)
            }
        }
    }

    if let previousFactCheckAttribute = previousMessage.attributes.first(where: { $0 is FactCheckMessageAttribute }) as? FactCheckMessageAttribute, let updatedFactCheckAttribute = message.attributes.first(where: { $0 is FactCheckMessageAttribute }) as? FactCheckMessageAttribute {
        if case .Pending = updatedFactCheckAttribute.content, updatedFactCheckAttribute.hash == previousFactCheckAttribute.hash {
            updatedAttributes.removeAll(where: { $0 is FactCheckMessageAttribute })
            updatedAttributes.append(previousFactCheckAttribute)
        }
    }

    // KittyGram: carry the deleted marker over and record the previous text when the server edits a message.
    if let deletedAttribute = previousMessage.attributes.first(where: { $0 is KittyGramDeletedMessageAttribute }), !updatedAttributes.contains(where: { $0 is KittyGramDeletedMessageAttribute }) {
        updatedAttributes.append(deletedAttribute)
    }
    var kittyGramVersions = previousMessage.kittyGramEditVersions
    if KittyGramSettings.shared.saveEdits {
        // A replaced photo / video / file counts as an edit too (link previews do not).
        func kittyGramMediaIds(_ media: [Media]) -> [MediaId] {
            return media.filter { !($0 is TelegramMediaWebpage) }.compactMap { $0.id }
        }
        let previousMediaIds = kittyGramMediaIds(previousMessage.media)
        let mediaChanged = !previousMediaIds.isEmpty && previousMediaIds != kittyGramMediaIds(message.media)
        let textChanged = previousMessage.text != message.text && !previousMessage.text.isEmpty
        if textChanged || mediaChanged {
            let previousMedia = mediaChanged ? previousMessage.media.filter { !($0 is TelegramMediaWebpage) } : []
            kittyGramVersions.append(KittyGramEditVersion(text: previousMessage.text, date: previousMessage.editedTime ?? previousMessage.timestamp, media: previousMedia))
        }
    }
    updatedAttributes.removeAll(where: { $0 is KittyGramEditHistoryAttribute })
    if !kittyGramVersions.isEmpty {
        updatedAttributes.append(KittyGramEditHistoryAttribute(versions: kittyGramVersions))
    }

    var updatedMedia = message.media
    if let previousPaidContent = previousMessage.media.first(where: { $0 is TelegramMediaPaidContent }) as? TelegramMediaPaidContent, case .full = previousPaidContent.extendedMedia.first {
        updatedMedia = previousMessage.media
    }

    return message.withUpdatedLocalTags(updatedLocalTags).withUpdatedFlags(updatedFlags).withUpdatedAttributes(updatedAttributes).withUpdatedMedia(updatedMedia)
}
