import Foundation
import Postbox

/// "Notify About Deletions / Edits": TelegramCore cannot show notifications itself, so it announces the event and the
/// app shows it (TelegramUI observes `KittyGramMessageEvent.notification`).
public struct KittyGramMessageEvent {
    public enum Kind {
        case deleted
        case edited
    }

    public static let notification = Notification.Name("KittyGramMessageEvent")

    public let kind: Kind
    public let peerId: PeerId
    public let messageId: Int32
    public let authorName: String
    public let text: String
    public let newText: String?
    public let hasMedia: Bool
}

/// Called while a deletion is kept or an edit is recorded. Only messages the other person wrote in a private chat
/// (not bots) are announced, and only when the matching switch is on.
func kittyGramPostMessageEvent(kind: KittyGramMessageEvent.Kind, message: Message, newText: String?) {
    let settings = KittyGramSettings.shared
    switch kind {
    case .deleted:
        if !settings.bool("notifyDeleted") {
            return
        }
    case .edited:
        if !settings.bool("notifyEdited") {
            return
        }
    }
    guard message.id.peerId.namespace == Namespaces.Peer.CloudUser, message.flags.contains(.Incoming) else {
        return
    }
    if let user = message.peers[message.id.peerId] as? TelegramUser, user.botInfo != nil {
        return
    }
    let event = KittyGramMessageEvent(
        kind: kind,
        peerId: message.id.peerId,
        messageId: message.id.id,
        authorName: message.author?.debugDisplayTitle ?? "",
        text: message.text,
        newText: newText,
        hasMedia: message.media.contains(where: { !($0 is TelegramMediaWebpage) })
    )
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: KittyGramMessageEvent.notification, object: nil, userInfo: ["event": event])
    }
}
