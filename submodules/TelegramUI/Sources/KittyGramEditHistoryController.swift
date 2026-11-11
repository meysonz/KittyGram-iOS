import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramStringFormatting
import SettingsUI

private final class KittyGramEditHistoryArguments {
    let context: AccountContext
    var presentationData: PresentationData
    let messages: [EngineMessage]

    init(context: AccountContext, presentationData: PresentationData, messages: [EngineMessage]) {
        self.context = context
        self.presentationData = presentationData
        self.messages = messages
    }
}

private enum KittyGramEditHistoryEntry: ItemListNodeEntry {
    case header(Int32, String, Int32)
    case bubble(Int32, Int, Int32)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, _, section), let .bubble(_, _, section):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .bubble(id, _, _):
            return id
        }
    }

    static func <(lhs: KittyGramEditHistoryEntry, rhs: KittyGramEditHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KittyGramEditHistoryArguments
        switch self {
        case let .header(_, text, section):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .bubble(_, index, section):
            let messages = index >= 0 && index < arguments.messages.count ? [arguments.messages[index]] : []
            return kittyGramMessageBubblesItem(context: arguments.context, presentationData: arguments.presentationData, messages: messages, sectionId: section)
        }
    }
}

/// A copy of the message as it was in one version: its text and media then, without edit marks, reactions or buttons.
private func kittyGramVersionMessage(_ message: EngineMessage, text: String, media: [EngineRawMedia], timestamp: Int32, stableId: UInt32) -> EngineMessage {
    let raw = message._asMessage()
    let attributes: [EngineMessage.Attribute] = raw.attributes.filter { attribute in
        if attribute is KittyGramEditHistoryAttribute || attribute is KittyGramDeletedMessageAttribute || attribute is EditedMessageAttribute {
            return false
        }
        if attribute is ReactionsMessageAttribute || attribute is ReplyMarkupMessageAttribute || attribute is TextEntitiesMessageAttribute {
            return false
        }
        return true
    }
    return EngineMessage(EngineRawMessage(stableId: stableId, stableVersion: 0, id: raw.id, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: raw.threadId, timestamp: timestamp, flags: raw.flags, tags: raw.tags, globalTags: raw.globalTags, localTags: raw.localTags, customTags: raw.customTags, forwardInfo: raw.forwardInfo, author: raw.author, text: text, attributes: attributes, media: media, peers: raw.peers, associatedMessages: raw.associatedMessages, associatedMessageIds: raw.associatedMessageIds, associatedMedia: raw.associatedMedia, associatedThreadInfo: raw.associatedThreadInfo, associatedStories: raw.associatedStories))
}

/// Shows every saved earlier version of an edited message as a chat bubble, oldest first, and the current one last.
func kittyGramEditHistoryController(context: AccountContext, message: EngineMessage) -> ViewController {
    let raw = message._asMessage()
    let versions = raw.kittyGramEditVersions

    // A version that stored no media had the same media as the version after it.
    var mediaForVersion: [[EngineRawMedia]] = Array(repeating: [], count: versions.count)
    var mediaAfter: [EngineRawMedia] = raw.media.filter { !($0 is TelegramMediaWebpage) }
    for index in (0 ..< versions.count).reversed() {
        let media = versions[index].media.isEmpty ? mediaAfter : versions[index].media
        mediaForVersion[index] = media
        mediaAfter = media
    }

    var messages: [EngineMessage] = []
    for (index, version) in versions.enumerated() {
        messages.append(kittyGramVersionMessage(message, text: version.text, media: mediaForVersion[index], timestamp: version.date > 0 ? version.date : raw.timestamp, stableId: UInt32(1000 + index)))
    }
    messages.append(kittyGramVersionMessage(message, text: raw.text, media: raw.media, timestamp: raw.editedTime ?? raw.timestamp, stableId: UInt32(1000 + versions.count)))
    let initialPresentationData = context.sharedContext.currentPresentationData.with { $0 }
    let arguments = KittyGramEditHistoryArguments(context: context, presentationData: initialPresentationData, messages: messages)

    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        arguments.presentationData = presentationData
        let isRussian = presentationData.strings.primaryComponent.languageCode == "ru"
        var entries: [KittyGramEditHistoryEntry] = []
        var nextId: Int32 = 0
        for index in 0 ..< messages.count {
            nextId += 1
            let isCurrent = index == messages.count - 1
            let timestamp = messages[index].timestamp
            let dateText = stringForFullDate(timestamp: timestamp, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
            let title: String
            if isCurrent {
                title = (isRussian ? "СЕЙЧАС" : "CURRENT") + " · " + dateText.uppercased()
            } else {
                title = (isRussian ? "ВЕРСИЯ " : "VERSION ") + "\(index + 1) · " + dateText.uppercased()
            }
            entries.append(.header(nextId, title, Int32(index)))
            nextId += 1
            entries.append(.bubble(nextId, index, Int32(index)))
        }

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(isRussian ? "История" : "History"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
