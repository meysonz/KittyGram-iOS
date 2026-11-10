import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class KittyGramSettingsArguments {
    let toggle: (String, Bool) -> Void
    let toggleGhostExpanded: () -> Void

    init(toggle: @escaping (String, Bool) -> Void, toggleGhostExpanded: @escaping () -> Void) {
        self.toggle = toggle
        self.toggleGhostExpanded = toggleGhostExpanded
    }
}

private struct KittyGramGhostOption: Equatable {
    let key: String
    let title: String
    let isOn: Bool
}

private enum KittyGramSettingsEntry: ItemListNodeEntry {
    case header(Int32, String, Int32)
    case ghost(Int32, String, Bool, Bool, [KittyGramGhostOption], Int32)
    case toggle(Int32, String, String, Bool, Int32)
    case choice(Int32, String, String, String, Int32)
    case footer(Int32, String, Int32)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, _, section), let .ghost(_, _, _, _, _, section), let .toggle(_, _, _, _, section), let .choice(_, _, _, _, section), let .footer(_, _, section):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .ghost(id, _, _, _, _, _), let .toggle(id, _, _, _, _), let .choice(id, _, _, _, _), let .footer(id, _, _):
            return id
        }
    }

    static func <(lhs: KittyGramSettingsEntry, rhs: KittyGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KittyGramSettingsArguments
        switch self {
        case let .header(_, text, section):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .ghost(_, title, value, isExpanded, options, section):
            return ItemListExpandableSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, isExpanded: isExpanded, subItems: options.map { option in
                return ItemListExpandableSwitchItem.SubItem(id: AnyHashable(option.key), title: option.title, isSelected: option.isOn, isEnabled: true)
            }, sectionId: section, style: .blocks, updated: { updatedValue in
                arguments.toggle("ghost", updatedValue)
            }, selectAction: {
                arguments.toggleGhostExpanded()
            }, subAction: { subItem in
                if let key = subItem.id.base as? String {
                    arguments.toggle(key, !subItem.isSelected)
                }
            })
        case let .toggle(_, key, title, value, section):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: section, style: .blocks, updated: { updatedValue in
                arguments.toggle(key, updatedValue)
            })
        case let .choice(_, key, title, label, section):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: section, style: .blocks, action: {
                arguments.toggle(key, true)
            })
        case let .footer(_, text, section):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        }
    }
}

private func kittyGramSettingsEntries(isRussian: Bool, ghostExpanded: Bool) -> [KittyGramSettingsEntry] {
    func tr(_ en: String, _ ru: String) -> String {
        return isRussian ? ru : en
    }

    let settings = KittyGramSettings.shared
    var entries: [KittyGramSettingsEntry] = []
    var nextId: Int32 = 0
    func id() -> Int32 {
        nextId += 1
        return nextId
    }

    // Ghost
    entries.append(.header(id(), tr("GHOST ESSENTIALS", "РЕЖИМ ПРИЗРАКА"), 0))
    let ghostOptions: [KittyGramGhostOption] = [
        KittyGramGhostOption(key: "hideRead", title: tr("Don't Send Read Receipts", "Не отправлять «прочитано»"), isOn: settings.hideRead),
        KittyGramGhostOption(key: "hideStoryViews", title: tr("Don't Send Story Views", "Не отправлять просмотры историй"), isOn: settings.hideStoryViews),
        KittyGramGhostOption(key: "hideOnline", title: tr("Don't Send Online", "Не отправлять «в сети»"), isOn: settings.hideOnline),
        KittyGramGhostOption(key: "hideTyping", title: tr("Don't Send Typing", "Не отправлять «печатает»"), isOn: settings.hideTyping),
        KittyGramGhostOption(key: "offlineAfterOnline", title: tr("Go Offline Automatically", "Сразу уходить «не в сети»"), isOn: settings.offlineAfterOnline)
    ]
    entries.append(.ghost(id(), tr("Ghost Mode", "Режим призрака"), settings.activeGhostFlagCount > 0, ghostExpanded, ghostOptions, 0))
    entries.append(.toggle(id(), "readOnInteract", tr("Read on Reply", "Прочитать при ответе"), settings.readOnInteract, 0))
    let soundLabels = [tr("Never", "Никогда"), tr("In Ghost Mode", "В режиме призрака"), tr("Always", "Всегда")]
    entries.append(.choice(id(), "sendWithoutSound", tr("Send without Sound", "Отправлять без звука"), soundLabels[max(0, min(2, settings.sendWithoutSound))], 0))
    entries.append(.footer(id(), tr("Tap the row to see each option. \"Read on Reply\" marks the chat as read when you send a message there. Long-press the app icon and choose \"Enter Ghost Mode\" to turn everything on before the app connects.", "Нажми на строку, чтобы увидеть все функции. «Прочитать при ответе» отмечает чат прочитанным, когда ты отправляешь в него сообщение. Зажми иконку приложения и выбери «Войти в режиме призрака», чтобы всё включилось ещё до подключения."), 0))

    // Spy: saving
    entries.append(.header(id(), tr("SPY ESSENTIALS", "СОХРАНЕНИЕ"), 1))
    entries.append(.toggle(id(), "saveDeleted", tr("Save Deleted Messages", "Сохранять удалённые сообщения"), settings.saveDeleted, 1))
    entries.append(.toggle(id(), "saveEdits", tr("Save Edit History", "Хранить историю правок"), settings.saveEdits, 1))
    entries.append(.toggle(id(), "saveInBots", tr("Save in Bot Dialogs", "Сохранять в диалогах с ботами"), settings.saveInBots, 1))
    entries.append(.toggle(id(), "keepSelfDestructing", tr("Keep Self-Destructing Media", "Не сжигать исчезающие медиа"), settings.keepSelfDestructing, 1))
    entries.append(.footer(id(), tr("Self-destructing photos, videos and voice messages open without starting their timer, so they stay and the sender does not see that they were opened. Everything is stored only on this device.", "Исчезающие фото, видео и голосовые открываются без запуска таймера: они не пропадают, и отправитель не видит, что их открыли. Всё хранится только на этом устройстве."), 1))

    // Chats
    entries.append(.header(id(), tr("CHATS", "ЧАТЫ"), 2))
    entries.append(.toggle(id(), "showSeconds", tr("Show Message Seconds", "Секунды у времени сообщений"), settings.showSeconds, 2))
    entries.append(.toggle(id(), "showPeerId", tr("Show Peer ID", "Показывать ID в профиле"), settings.showPeerId, 2))

    return entries
}

private func applyKittyGramToggle(key: String, value: Bool) {
    let settings = KittyGramSettings.shared
    switch key {
    case "ghost":
        settings.ghostMode = value
    case "hideRead":
        settings.hideRead = value
    case "hideStoryViews":
        settings.hideStoryViews = value
    case "hideOnline":
        settings.hideOnline = value
    case "hideTyping":
        settings.hideTyping = value
    case "offlineAfterOnline":
        settings.offlineAfterOnline = value
    case "readOnInteract":
        settings.readOnInteract = value
    case "sendWithoutSound":
        settings.sendWithoutSound = (settings.sendWithoutSound + 1) % 3
    case "saveDeleted":
        settings.saveDeleted = value
    case "saveEdits":
        settings.saveEdits = value
    case "saveInBots":
        settings.saveInBots = value
    case "keepSelfDestructing":
        settings.keepSelfDestructing = value
    case "showPeerId":
        settings.showPeerId = value
    case "showSeconds":
        settings.showSeconds = value
    default:
        break
    }
}

public func kittyGramSettingsController(context: AccountContext) -> ViewController {
    let refresh = ValuePromise<Int>(0, ignoreRepeated: false)
    var refreshCounter = 0

    var ghostExpanded = false

    let arguments = KittyGramSettingsArguments(toggle: { key, value in
        applyKittyGramToggle(key: key, value: value)
        refreshCounter += 1
        refresh.set(refreshCounter)
    }, toggleGhostExpanded: {
        ghostExpanded = !ghostExpanded
        refreshCounter += 1
        refresh.set(refreshCounter)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        refresh.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isRussian = presentationData.strings.primaryComponent.languageCode == "ru"
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("KittyGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: kittyGramSettingsEntries(isRussian: isRussian, ghostExpanded: ghostExpanded), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
