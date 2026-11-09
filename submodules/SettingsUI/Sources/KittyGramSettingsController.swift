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

    init(toggle: @escaping (String, Bool) -> Void) {
        self.toggle = toggle
    }
}

private enum KittyGramSettingsEntry: ItemListNodeEntry {
    case header(Int32, String, Int32)
    case toggle(Int32, String, String, Bool, Int32)
    case choice(Int32, String, String, String, Int32)
    case footer(Int32, String, Int32)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, _, section), let .toggle(_, _, _, _, section), let .choice(_, _, _, _, section), let .footer(_, _, section):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _), let .choice(id, _, _, _, _), let .footer(id, _, _):
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

private func kittyGramSettingsEntries(isRussian: Bool) -> [KittyGramSettingsEntry] {
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

    // Ghost mode
    entries.append(.header(id(), tr("GHOST MODE", "РЕЖИМ ПРИЗРАКА"), 0))
    entries.append(.toggle(id(), "ghost", tr("Ghost Mode", "Режим призрака"), settings.ghostMode, 0))
    entries.append(.toggle(id(), "hideRead", tr("Don't Send Read Receipts", "Не отправлять «прочитано»"), settings.hideRead, 0))
    entries.append(.toggle(id(), "hideStoryViews", tr("Don't Send Story Views", "Не отправлять просмотры историй"), settings.hideStoryViews, 0))
    entries.append(.toggle(id(), "hideOnline", tr("Don't Send Online Status", "Не отправлять «в сети»"), settings.hideOnline, 0))
    entries.append(.toggle(id(), "hideTyping", tr("Don't Send Typing", "Не отправлять «печатает»"), settings.hideTyping, 0))
    entries.append(.toggle(id(), "offlineAfterOnline", tr("Send Offline After Online", "Сразу отправлять «не в сети»"), settings.offlineAfterOnline, 0))
    entries.append(.footer(id(), tr("The master switch turns the five options above on or off together. Read receipts are kept on this device only.", "Главный переключатель включает или выключает пять функций выше. «Прочитано» остаётся только на этом устройстве."), 0))

    entries.append(.toggle(id(), "readOnInteract", tr("Read on Interact", "Прочитать при действии"), settings.readOnInteract, 1))
    entries.append(.toggle(id(), "homeShortcut", tr("Home Screen Shortcut", "Ярлык на экране «Домой»"), settings.homeShortcut, 1))
    let soundLabels = [tr("Never", "Никогда"), tr("In Ghost Mode", "В режиме призрака"), tr("Always", "Всегда")]
    entries.append(.choice(id(), "sendWithoutSound", tr("Send without Sound", "Отправлять без звука"), soundLabels[max(0, min(2, settings.sendWithoutSound))], 1))
    entries.append(.footer(id(), tr("The shortcut adds \"Enter Ghost Mode\" to the app icon menu. Launching from it turns every ghost option on.", "Ярлык добавляет «Войти в режиме призрака» в меню иконки приложения. Запуск через него включает все функции призрака."), 1))

    // Saved messages
    entries.append(.header(id(), tr("SAVED MESSAGES", "СОХРАНЁННЫЕ СООБЩЕНИЯ"), 2))
    entries.append(.toggle(id(), "saveDeleted", tr("Save Deleted Messages", "Сохранять удалённые сообщения"), settings.saveDeleted, 2))
    entries.append(.toggle(id(), "saveEdits", tr("Save Edit History", "Хранить историю правок"), settings.saveEdits, 2))
    entries.append(.toggle(id(), "saveInBots", tr("Save in Bot Dialogs", "Сохранять в диалогах с ботами"), settings.saveInBots, 2))
    entries.append(.footer(id(), tr("Stored only on this device.", "Хранится только на этом устройстве."), 2))

    // General
    entries.append(.header(id(), tr("GENERAL", "ОБЩИЕ"), 3))
    entries.append(.toggle(id(), "showPeerId", tr("Show Peer ID", "Показывать ID"), settings.showPeerId, 3))
    entries.append(.toggle(id(), "showSeconds", tr("Show Message Seconds", "Показывать секунды у сообщений"), settings.showSeconds, 3))

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
    case "homeShortcut":
        settings.homeShortcut = value
    case "sendWithoutSound":
        settings.sendWithoutSound = (settings.sendWithoutSound + 1) % 3
    case "saveDeleted":
        settings.saveDeleted = value
    case "saveEdits":
        settings.saveEdits = value
    case "saveInBots":
        settings.saveInBots = value
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

    let arguments = KittyGramSettingsArguments(toggle: { key, value in
        applyKittyGramToggle(key: key, value: value)
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
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: kittyGramSettingsEntries(isRussian: isRussian), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
