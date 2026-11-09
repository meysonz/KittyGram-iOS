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

private final class KittyGramEditHistoryArguments {
}

private enum KittyGramEditHistoryEntry: ItemListNodeEntry {
    case version(Int32, String, String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case let .version(index, _, _):
            return index
        }
    }

    static func <(lhs: KittyGramEditHistoryEntry, rhs: KittyGramEditHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .version(_, label, text):
            return ItemListTextWithLabelItem(presentationData: presentationData, label: label, text: text, style: .blocks, enabledEntityTypes: [], multiline: true, sectionId: self.section, action: nil)
        }
    }
}

/// Shows every saved earlier version of an edited message, oldest first, followed by the current text.
func kittyGramEditHistoryController(context: AccountContext, versions: [KittyGramEditVersion], currentText: String) -> ViewController {
    let arguments = KittyGramEditHistoryArguments()

    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isRussian = presentationData.strings.primaryComponent.languageCode == "ru"
        var entries: [KittyGramEditHistoryEntry] = []
        var index: Int32 = 0
        for version in versions {
            index += 1
            let dateText = version.date > 0 ? stringForFullDate(timestamp: version.date, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat) : ""
            let label = (isRussian ? "Версия " : "Version ") + "\(index)" + (dateText.isEmpty ? "" : " · " + dateText)
            entries.append(.version(index, label, version.text))
        }
        index += 1
        entries.append(.version(index, isRussian ? "Сейчас" : "Current", currentText))

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(isRussian ? "История" : "History"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
