import Foundation
import Postbox

/// One earlier version of an edited message: its text and, when the photo / video / file was replaced, the old media.
public struct KittyGramEditVersion: Equatable {
    public let text: String
    public let date: Int32
    public let media: [Media]

    public init(text: String, date: Int32, media: [Media] = []) {
        self.text = text
        self.date = date
        self.media = media
    }

    public static func ==(lhs: KittyGramEditVersion, rhs: KittyGramEditVersion) -> Bool {
        if lhs.text != rhs.text || lhs.date != rhs.date || lhs.media.count != rhs.media.count {
            return false
        }
        for i in 0 ..< lhs.media.count {
            if !lhs.media[i].isEqual(to: rhs.media[i]) {
                return false
            }
        }
        return true
    }
}

/// All earlier versions of a message, oldest first. Added when the server edits a message and "Save Edit History" is on.
public final class KittyGramEditHistoryAttribute: MessageAttribute {
    public let versions: [KittyGramEditVersion]

    public init(versions: [KittyGramEditVersion]) {
        self.versions = versions
    }

    required public init(decoder: PostboxDecoder) {
        let texts = decoder.decodeStringArrayForKey("t")
        let dates = decoder.decodeInt32ArrayForKey("d")
        let mediaIndices = decoder.decodeInt32ArrayForKey("mi")
        let mediaObjects = decoder.decodeObjectArrayForKey("mo")
        var mediaByVersion: [Int: [Media]] = [:]
        for i in 0 ..< min(mediaIndices.count, mediaObjects.count) {
            if let media = mediaObjects[i] as? Media {
                mediaByVersion[Int(mediaIndices[i]), default: []].append(media)
            }
        }
        var versions: [KittyGramEditVersion] = []
        var index = 0
        while index < texts.count {
            versions.append(KittyGramEditVersion(text: texts[index], date: index < dates.count ? dates[index] : 0, media: mediaByVersion[index] ?? []))
            index += 1
        }
        self.versions = versions
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(self.versions.map { $0.text }, forKey: "t")
        encoder.encodeInt32Array(self.versions.map { $0.date }, forKey: "d")
        var mediaIndices: [Int32] = []
        var mediaObjects: [PostboxCoding] = []
        for (index, version) in self.versions.enumerated() {
            for media in version.media {
                mediaIndices.append(Int32(index))
                mediaObjects.append(media)
            }
        }
        encoder.encodeInt32Array(mediaIndices, forKey: "mi")
        encoder.encodeGenericObjectArray(mediaObjects, forKey: "mo")
    }
}

/// Marks a message that was deleted on the server but is kept on this device.
public final class KittyGramDeletedMessageAttribute: MessageAttribute {
    public let deletedDate: Int32

    public init(deletedDate: Int32) {
        self.deletedDate = deletedDate
    }

    required public init(decoder: PostboxDecoder) {
        self.deletedDate = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.deletedDate, forKey: "d")
    }
}

public extension Message {
    /// A timer or view-once photo / video / voice / video message (not a message of a chat with auto-delete on).
    var kittyGramIsSelfDestructingMedia: Bool {
        return self.containsSecretMedia || self.minAutoremoveOrClearTimeout == viewOnceTimeout
    }

    /// "Keep Self-Destructing Media" applies: such media of a normal (not secret) chat.
    var kittyGramKeepsSelfDestructingMedia: Bool {
        return KittyGramSettings.shared.keepSelfDestructing && self.id.peerId.namespace != Namespaces.Peer.SecretChat && self.kittyGramIsSelfDestructingMedia
    }

    /// "Self-Destructing Media Screenshots": a timer / view-once media of a normal chat may be captured on screen.
    /// Never for secret chats, and never for content the chat itself protects.
    var kittyGramAllowsSelfDestructCapture: Bool {
        if !KittyGramSettings.shared.selfDestructScreenshots {
            return false
        }
        if self.id.peerId.namespace == Namespaces.Peer.SecretChat || self.isCopyProtected() {
            return false
        }
        return self.kittyGramIsSelfDestructingMedia
    }

    var kittyGramIsDeleted: Bool {
        return self.attributes.contains(where: { $0 is KittyGramDeletedMessageAttribute })
    }

    var kittyGramEditVersions: [KittyGramEditVersion] {
        for attribute in self.attributes {
            if let attribute = attribute as? KittyGramEditHistoryAttribute {
                return attribute.versions
            }
        }
        return []
    }
}

/// Keeps the given messages on this device, marked as deleted. Returns the ids that were kept; the caller deletes the rest.
func kittyGramMarkMessagesDeleted(transaction: Transaction, ids: [MessageId]) -> Set<MessageId> {
    var kept = Set<MessageId>()
    let now = Int32(Date().timeIntervalSince1970)
    for id in ids {
        guard let message = transaction.getMessage(id) else {
            continue
        }
        if message.id.namespace != Namespaces.Message.Cloud {
            continue
        }
        if !KittyGramSettings.shared.saveInBots, let user = message.peers[message.id.peerId] as? TelegramUser, user.botInfo != nil {
            continue
        }
        if message.attributes.contains(where: { $0 is KittyGramDeletedMessageAttribute }) {
            kept.insert(id)
            continue
        }
        kittyGramPostMessageEvent(kind: .deleted, message: message, newText: nil)
        transaction.updateMessage(id, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var updatedAttributes = currentMessage.attributes
            updatedAttributes.append(KittyGramDeletedMessageAttribute(deletedDate: now))
            return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
        })
        kept.insert(id)
    }
    return kept
}
