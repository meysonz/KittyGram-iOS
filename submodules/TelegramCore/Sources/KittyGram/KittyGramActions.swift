import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
internal import TelegramApi

/// Runs after the server accepted an outgoing message.
/// - "Read on Reply": while read receipts are hidden, answering in a chat marks it read for the sender too.
/// - "Go offline automatically" / hidden online: sending can show the account online, so report offline again.
func kittyGramAfterMessageSent(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId) {
    let settings = KittyGramSettings.shared
    if settings.hideRead && settings.readOnInteract {
        let _ = kittyGramPushPeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId).start()
    }
    if settings.offlineAfterOnline || settings.hideOnline {
        let _ = network.request(Api.functions.account.updateStatus(offline: .boolTrue)).start(error: { _ in
        })
    }
}

public extension TelegramEngine.Messages {
    /// The "Read" context menu item: marks the chat read up to `index` locally and tells the server, even in ghost mode.
    func kittyGramReadMessages(upTo index: MessageIndex) -> Signal<Never, NoError> {
        let account = self.account
        return account.postbox.transaction { transaction -> Void in
            _internal_applyMaxReadIndexInteractively(transaction: transaction, stateManager: account.stateManager, index: index)
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            return kittyGramPushPeerReadState(network: account.network, postbox: account.postbox, stateManager: account.stateManager, peerId: index.id.peerId)
        }
    }
}

public extension TelegramEngine.Messages {
    /// The account's own status as other people see it. Telegram never stores it (the profile always says "online"),
    /// which is wrong in ghost mode; ask the server instead, again every minute while someone listens.
    func kittyGramOwnPresence() -> Signal<TelegramUserPresence?, NoError> {
        let network = self.account.network
        let once: Signal<TelegramUserPresence?, NoError> = network.request(Api.functions.users.getUsers(id: [.inputUserSelf]))
        |> map { users -> TelegramUserPresence? in
            for user in users {
                if let presence = TelegramUserPresence(apiUser: user) {
                    return presence
                }
            }
            return nil
        }
        |> `catch` { _ -> Signal<TelegramUserPresence?, NoError> in
            return .single(nil)
        }
        return (once |> then(Signal<TelegramUserPresence?, NoError>.complete() |> delay(60.0, queue: Queue.concurrentDefaultQueue())))
        |> restart
    }
}
