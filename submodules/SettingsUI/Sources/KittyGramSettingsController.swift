import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import PromptUI

/// The pages of KittyGram's settings, like AyuGram's: a main page with categories and one page per category.
public enum KittyGramSettingsPage {
    case main
    case kittyGram
    case filters
    case general
    case appearance
    case chats
}

/// KittyGram's own alternate app icons. The primary icon (Lavender) is selected by clearing the alternate icon.
let kittyGramAppIcons: [PresentationAppIcon] = [
    PresentationAppIcon(name: "KittyLavenderIcon", imageName: "KittyLavenderIcon", isDefault: true),
    PresentationAppIcon(name: "KittySkyIcon", imageName: "KittySkyIcon"),
    PresentationAppIcon(name: "KittyMonoIcon", imageName: "KittyMonoIcon"),
    PresentationAppIcon(name: "KittyCherryIcon", imageName: "KittyCherryIcon"),
    PresentationAppIcon(name: "KittyCatFaceIcon", imageName: "KittyCatFaceIcon"),
    PresentationAppIcon(name: "KittyCatTailIcon", imageName: "KittyCatTailIcon")
]

private struct KittyGramOption: Equatable {
    let key: String
    let title: String
    let isOn: Bool
}

private final class KittyGramSettingsArguments {
    let context: AccountContext
    var presentationData: PresentationData
    var currentIconName: String?
    let toggle: (String, Bool) -> Void
    let toggleGroup: (String, Bool) -> Void
    let toggleExpanded: (String) -> Void
    let openPage: (KittyGramSettingsPage) -> Void
    let openChoice: (String) -> Void
    let setSlider: (String, Int) -> Void
    let setIcon: (PresentationAppIcon) -> Void
    let addPhrase: () -> Void
    let removePhrase: (Int) -> Void
    let openUrl: (String) -> Void

    init(context: AccountContext, presentationData: PresentationData, currentIconName: String?, toggle: @escaping (String, Bool) -> Void, toggleGroup: @escaping (String, Bool) -> Void, toggleExpanded: @escaping (String) -> Void, openPage: @escaping (KittyGramSettingsPage) -> Void, openChoice: @escaping (String) -> Void, setSlider: @escaping (String, Int) -> Void, setIcon: @escaping (PresentationAppIcon) -> Void, addPhrase: @escaping () -> Void, removePhrase: @escaping (Int) -> Void, openUrl: @escaping (String) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.currentIconName = currentIconName
        self.toggle = toggle
        self.toggleGroup = toggleGroup
        self.toggleExpanded = toggleExpanded
        self.openPage = openPage
        self.openChoice = openChoice
        self.setSlider = setSlider
        self.setIcon = setIcon
        self.addPhrase = addPhrase
        self.removePhrase = removePhrase
        self.openUrl = openUrl
    }
}

private enum KittyGramIcon: Equatable {
    case kittyGram
    case filters
    case general
    case appearance
    case chats
    case link

    var image: UIImage? {
        switch self {
        case .kittyGram:
            return KittyGramCategoryIcons.kittyGram
        case .filters:
            return KittyGramCategoryIcons.filters
        case .general:
            return KittyGramCategoryIcons.general
        case .appearance:
            return KittyGramCategoryIcons.appearance
        case .chats:
            return KittyGramCategoryIcons.chats
        case .link:
            return KittyGramCategoryIcons.link
        }
    }
}

private enum KittyGramCategoryIcons {
    static let kittyGram = renderSettingsIcon(name: "Item List/Icons/KittyGram", backgroundColors: [UIColor(rgb: 0x7B4AE8), UIColor(rgb: 0xB9A0FF)])
    static let filters = renderSettingsIcon(name: "Item List/Icons/Tag", backgroundColors: [UIColor(rgb: 0xFF453A)])
    static let general = renderSettingsIcon(name: "Item List/Icons/Settings", backgroundColors: [UIColor(rgb: 0x8E8E93)])
    static let appearance = renderSettingsIcon(name: "Item List/Icons/Brush", backgroundColors: [UIColor(rgb: 0x32ADE6)])
    static let chats = renderSettingsIcon(name: "Item List/Icons/Chat", backgroundColors: [UIColor(rgb: 0x34C759)])
    static let link = renderSettingsIcon(name: "Item List/Icons/Link", backgroundColors: [UIColor(rgb: 0x0A84FF)])
}

private enum KittyGramSettingsEntry: ItemListNodeEntry {
    case logo(Int32, String, String, Int32)
    case category(Int32, KittyGramSettingsPage, KittyGramIcon, String, String, Int32)
    case link(Int32, String, String, String, Int32)
    case header(Int32, String, Int32)
    case toggle(Int32, String, String, Bool, Int32)
    case group(Int32, String, String, Bool, Bool, [KittyGramOption], Int32)
    case choice(Int32, String, String, String, Int32)
    case footer(Int32, String, Int32)
    case slider(Int32, String, Int, Int, Int32)
    case avatarPreview(Int32, Int, String, String, Int32)
    case preview(Int32, Int, Int32)
    case icons(Int32, String?, Int32)
    case phrase(Int32, Int, String, Int32)
    case addPhrase(Int32, String, Int32)

    var section: ItemListSectionId {
        switch self {
        case let .logo(_, _, _, section), let .category(_, _, _, _, _, section), let .link(_, _, _, _, section), let .header(_, _, section), let .toggle(_, _, _, _, section), let .group(_, _, _, _, _, _, section), let .choice(_, _, _, _, section), let .footer(_, _, section), let .slider(_, _, _, _, section), let .avatarPreview(_, _, _, _, section), let .preview(_, _, section), let .icons(_, _, section), let .phrase(_, _, _, section), let .addPhrase(_, _, section):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .logo(id, _, _, _), let .category(id, _, _, _, _, _), let .link(id, _, _, _, _), let .header(id, _, _), let .toggle(id, _, _, _, _), let .group(id, _, _, _, _, _, _), let .choice(id, _, _, _, _), let .footer(id, _, _), let .slider(id, _, _, _, _), let .avatarPreview(id, _, _, _, _), let .preview(id, _, _), let .icons(id, _, _), let .phrase(id, _, _, _), let .addPhrase(id, _, _):
            return id
        }
    }

    static func <(lhs: KittyGramSettingsEntry, rhs: KittyGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KittyGramSettingsArguments
        switch self {
        case let .logo(_, title, subtitle, section):
            return KittyGramLogoItem(theme: presentationData.theme, title: title, subtitle: subtitle, sectionId: section)
        case let .category(_, page, icon, title, label, section):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: icon.image, title: title, label: label, sectionId: section, style: .blocks, action: {
                arguments.openPage(page)
            })
        case let .link(_, title, label, url, section):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: KittyGramIcon.link.image, title: title, label: label, sectionId: section, style: .blocks, action: {
                arguments.openUrl(url)
            })
        case let .header(_, text, section):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .toggle(_, key, title, value, section):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: section, style: .blocks, updated: { updatedValue in
                arguments.toggle(key, updatedValue)
            })
        case let .group(_, groupKey, title, value, isExpanded, options, section):
            return ItemListExpandableSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, isExpanded: isExpanded, subItems: options.map { option in
                return ItemListExpandableSwitchItem.SubItem(id: AnyHashable(option.key), title: option.title, isSelected: option.isOn, isEnabled: true)
            }, sectionId: section, style: .blocks, updated: { updatedValue in
                arguments.toggleGroup(groupKey, updatedValue)
            }, selectAction: {
                arguments.toggleExpanded(groupKey)
            }, subAction: { subItem in
                if let key = subItem.id.base as? String {
                    arguments.toggle(key, !subItem.isSelected)
                }
            })
        case let .choice(_, key, title, label, section):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: section, style: .blocks, action: {
                arguments.openChoice(key)
            })
        case let .footer(_, text, section):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        case let .slider(_, key, value, valueCount, section):
            return KittyGramSliderItem(theme: presentationData.theme, valueCount: valueCount, value: value, sectionId: section, updated: { updatedValue in
                arguments.setSlider(key, updatedValue)
            })
        case let .avatarPreview(_, percent, title, subtitle, section):
            return KittyGramAvatarPreviewItem(theme: presentationData.theme, cornerFraction: CGFloat(max(0, min(50, percent))) / 100.0, title: title, subtitle: subtitle, sectionId: section)
        case let .preview(_, version, section):
            let data = arguments.presentationData
            let isRussian = data.strings.primaryComponent.languageCode == "ru"
            var incoming = ChatPreviewMessageItem(outgoing: false, reply: (isRussian ? "Мурка" : "Kitty", isRussian ? "Ты где?" : "Where are you?"), text: isRussian ? "Скоро буду, жди 🐾" : "Almost there, wait for me 🐾", nameColor: .preset(.violet), backgroundEmojiId: nil)
            incoming.kittyGramMarks = true
            incoming.kittyGramVersion = version
            return ThemeSettingsChatPreviewItem(context: arguments.context, systemStyle: .glass, theme: data.theme, componentTheme: data.theme, strings: data.strings, sectionId: section, fontSize: data.chatFontSize, chatBubbleCorners: data.chatBubbleCorners, wallpaper: data.chatWallpaper, dateTimeFormat: data.dateTimeFormat, nameDisplayOrder: data.nameDisplayOrder, messageItems: [incoming])
        case let .icons(_, currentIconName, section):
            return ThemeSettingsAppIconItem(theme: presentationData.theme, strings: presentationData.strings, systemStyle: .glass, sectionId: section, icons: kittyGramAppIcons, isPremium: false, currentIconName: currentIconName ?? "KittyLavenderIcon", updated: { icon in
                arguments.setIcon(icon)
            })
        case let .phrase(_, index, text, section):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: text, label: "", sectionId: section, style: .blocks, disclosureStyle: .none, action: {
                arguments.removePhrase(index)
            })
        case let .addPhrase(_, title, section):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: section, style: .blocks, action: {
                arguments.addPhrase()
            })
        }
    }
}

private func kittyGramVersionString() -> String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? ""
    let build = info?["CFBundleVersion"] as? String ?? ""
    return build.isEmpty ? version : "\(version) (\(build))"
}

private func kittyGramMarkLabel(_ value: String, isRussian: Bool) -> String {
    return value.isEmpty ? (isRussian ? "По умолчанию" : "Default") : value
}

private func kittyGramSettingsEntries(page: KittyGramSettingsPage, isRussian: Bool, expanded: Set<String>, version: Int, currentIconName: String?, bubbleRadius: Int) -> [KittyGramSettingsEntry] {
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
    func option(_ key: String, _ en: String, _ ru: String) -> KittyGramOption {
        return KittyGramOption(key: key, title: tr(en, ru), isOn: settings.bool(key))
    }
    func group(_ groupKey: String, _ en: String, _ ru: String, _ options: [KittyGramOption], _ section: Int32) {
        entries.append(.group(id(), groupKey, tr(en, ru), options.contains(where: { $0.isOn }), expanded.contains(groupKey), options, section))
    }
    func toggle(_ key: String, _ en: String, _ ru: String, _ section: Int32) {
        entries.append(.toggle(id(), key, tr(en, ru), settings.bool(key), section))
    }

    switch page {
    case .main:
        entries.append(.logo(id(), "KittyGram", tr("Version", "Версия") + " " + kittyGramVersionString(), 0))
        entries.append(.category(id(), .kittyGram, .kittyGram, "KittyGram", "", 1))
        entries.append(.category(id(), .filters, .filters, tr("Filters", "Фильтры"), settings.filterPhrases.isEmpty ? "" : "\(settings.filterPhrases.count)", 1))
        entries.append(.category(id(), .general, .general, tr("General", "Общие"), "", 1))
        entries.append(.category(id(), .appearance, .appearance, tr("Appearance", "Внешний вид"), "", 1))
        entries.append(.category(id(), .chats, .chats, tr("Chats", "Чаты"), "", 1))
        entries.append(.header(id(), tr("LINKS", "ССЫЛКИ"), 2))
        entries.append(.link(id(), tr("Source Code", "Исходный код"), "GitHub", "https://github.com/meysonz/KittyGram-iOS", 2))

    case .kittyGram:
        entries.append(.header(id(), tr("GHOST ESSENTIALS", "РЕЖИМ ПРИЗРАКА"), 0))
        group("ghost", "Ghost Mode", "Режим призрака", [
            option("hideRead", "Don't Send Read Receipts", "Не отправлять «прочитано»"),
            option("hideStoryViews", "Don't Send Story Views", "Не отправлять просмотры историй"),
            option("hideOnline", "Don't Send Online", "Не отправлять «в сети»"),
            option("hideTyping", "Don't Send Typing", "Не отправлять «печатает»"),
            option("offlineAfterOnline", "Go Offline Automatically", "Сразу уходить «не в сети»")
        ], 0)
        toggle("readOnInteract", "Read on Interact", "Прочитать при действии", 0)
        entries.append(.footer(id(), tr("Marks the chat as read when you send a message there or react to a message.", "Отмечает чат прочитанным, когда ты отправляешь в него сообщение или ставишь реакцию."), 0))

        let soundLabels = [tr("Never", "Никогда"), tr("In Ghost Mode", "В режиме призрака"), tr("Always", "Всегда")]
        entries.append(.choice(id(), "sendWithoutSound", tr("Send without Sound", "Отправлять без звука"), soundLabels[max(0, min(2, settings.sendWithoutSound))], 1))
        entries.append(.footer(id(), tr("Sends your messages without a notification sound.", "Отправляет твои сообщения без звука уведомления."), 1))

        toggle("storyGhostAlert", "Story Ghost Mode Alert", "Предупреждать перед историями", 2)
        entries.append(.footer(id(), tr("Before a story opens while story views are reported, asks whether to turn Ghost Mode on.", "Перед открытием истории спрашивает, включить ли режим призрака, если просмотры историй сейчас видны."), 2))

        entries.append(.header(id(), tr("SPY ESSENTIALS", "СОХРАНЕНИЕ"), 3))
        toggle("saveDeleted", "Save Deleted Messages", "Сохранять удалённые сообщения", 3)
        toggle("saveEdits", "Save Edits History", "Хранить историю правок", 3)
        toggle("saveInBots", "Save in Bot Dialogs", "Сохранять в диалогах с ботами", 3)
        toggle("keepSelfDestructing", "Keep Self-Destructing Media", "Не сжигать исчезающие медиа", 3)
        toggle("selfDestructScreenshots", "Self-Destructing Media Screenshots", "Скриншоты исчезающих медиа", 3)
        entries.append(.footer(id(), tr("Self-destructing photos, videos and voice messages open without starting their timer and can be saved or forwarded (as a copy). Screenshots of them are allowed and the sender is not told. Everything is kept only on this device.", "Исчезающие фото, видео и голосовые открываются без таймера, их можно сохранить или переслать (копией). Скриншоты разрешены, и отправитель о них не узнает. Всё хранится только на этом устройстве."), 3))

        entries.append(.header(id(), tr("OTHER", "ДРУГОЕ"), 4))
        toggle("disableAds", "Disable Ads", "Отключить рекламу", 4)

    case .filters:
        entries.append(.header(id(), tr("HIDE MESSAGES CONTAINING", "СКРЫВАТЬ СООБЩЕНИЯ СО СЛОВАМИ"), 0))
        for (index, phrase) in settings.filterPhrases.enumerated() {
            entries.append(.phrase(id(), index, phrase, 0))
        }
        entries.append(.addPhrase(id(), tr("Add Word or Phrase", "Добавить слово или фразу"), 0))
        entries.append(.footer(id(), tr("Messages that contain one of these words are hidden from chats. Tap a word to remove it.", "Сообщения с любым из этих слов скрываются из чатов. Нажми на слово, чтобы удалить его."), 0))

    case .general:
        entries.append(.header(id(), tr("NOTIFICATIONS", "УВЕДОМЛЕНИЯ"), 0))
        toggle("backgroundMode", "Work in Background", "Работать в фоне", 0)
        toggle("notificationText", "Show Message Text", "Текст в уведомлениях", 0)
        entries.append(.footer(id(), tr("KittyGram cannot receive push notifications. With \"Work in Background\" it stays connected after you leave it, shows a notification for every new message at once and saves deleted and edited messages right away. This uses more battery. Without it iOS wakes the app now and then to check for messages.", "KittyGram не может получать push-уведомления. С «Работать в фоне» он остаётся на связи после сворачивания, сразу показывает уведомление о каждом новом сообщении и сразу сохраняет удалённые и изменённые. Тратит больше батареи. Без этого iOS иногда будит приложение, чтобы проверить сообщения."), 0))

        entries.append(.header(id(), tr("GENERAL", "ОБЩИЕ"), 1))
        group("confirm", "Send Confirmations", "Подтверждать отправку", [
            option("confirmSticker", "Stickers", "Стикеры"),
            option("confirmGif", "GIFs", "GIF"),
            option("confirmVoice", "Voice Messages", "Голосовые"),
            option("confirmRound", "Video Messages", "Кружочки")
        ], 1)
        toggle("disableLinkWarning", "Disable Open Link Warning", "Без предупреждения о ссылках", 1)
        toggle("disableStories", "Disable Stories", "Отключить истории", 1)
        toggle("disableSimilarChannels", "Disable Similar Channels", "Отключить похожие каналы", 1)
        toggle("showPeerId", "Show Peer ID", "Показывать ID в профиле", 1)

    case .appearance:
        entries.append(.header(id(), tr("APP ICON", "ИКОНКА ПРИЛОЖЕНИЯ"), 0))
        entries.append(.icons(id(), currentIconName, 0))

        let avatarPercent = settings.avatarCornerPercent
        entries.append(.header(id(), tr("AVATAR CORNERS", "СКРУГЛЕНИЕ АВАТАРОК") + (avatarPercent >= 50 ? tr(" · CIRCLE", " · КРУГ") : " · \(avatarPercent * 2)%"), 1))
        entries.append(.avatarPreview(id(), avatarPercent, "KittyGram", tr("Avatar preview", "Так будут выглядеть аватарки"), 1))
        entries.append(.slider(id(), "avatarCornerPercent", avatarPercent / 5, 11, 1))

        entries.append(.header(id(), tr("CHAT LIST", "СПИСОК ЧАТОВ"), 2))
        toggle("hideNotificationCounters", "Hide Notification Counters", "Скрыть счётчики непрочитанных", 2)
        toggle("hideAllChatsTab", "Hide \"All Chats\" Tab", "Скрыть вкладку «Все чаты»", 2)
        toggle("disableCustomBackgrounds", "Disable Custom Backgrounds", "Отключить чужие фоны", 2)
        entries.append(.footer(id(), tr("Chats show your own background instead of the one set by the other person or the channel.", "В чатах всегда твой фон вместо обоев, которые поставил собеседник или канал."), 2))

    case .chats:
        entries.append(.header(id(), tr("MESSAGES", "СООБЩЕНИЯ"), 0))
        entries.append(.preview(id(), version, 0))
        toggle("replaceMarksWithIcons", "Replace with Icons", "Заменить иконками", 0)
        toggle("removeMessageTail", "Remove Message Tail", "Убрать хвостик у сообщений", 0)
        toggle("hideSideShareButton", "Hide Side \"Share\" Button", "Скрыть кнопку «Поделиться» сбоку", 0)
        toggle("disableColorfulReplies", "Disable Colorful Replies", "Отключить цветные ответы", 0)
        toggle("translucentDeleted", "Translucent Deleted Messages", "Полупрозрачные удалённые", 0)
        toggle("showSeconds", "Show Message Seconds", "Секунды у времени сообщений", 0)

        entries.append(.header(id(), tr("MESSAGE BUBBLE RADIUS", "СКРУГЛЕНИЕ ПУЗЫРЕЙ") + " · \(bubbleRadius)", 1))
        entries.append(.slider(id(), "bubbleRadius", bubbleRadius, 17, 1))

        entries.append(.header(id(), tr("MARKS", "МЕТКИ"), 2))
        entries.append(.choice(id(), "deletedMark", tr("Deleted Mark", "Метка удаления"), kittyGramMarkLabel(settings.deletedMark, isRussian: isRussian), 2))
        entries.append(.choice(id(), "editedMark", tr("Edited Mark", "Метка правки"), kittyGramMarkLabel(settings.editedMark, isRussian: isRussian), 2))

        entries.append(.header(id(), tr("STICKERS AND REACTIONS", "СТИКЕРЫ И РЕАКЦИИ"), 3))
        toggle("disableGreetingSticker", "Disable Greeting Sticker", "Скрыть приветственный стикер", 3)
        group("reactions", "Hide Reactions", "Скрыть реакции", [
            option("hideReactionsUnderMessages", "Under Messages", "Под сообщениями"),
            option("hideReactionsPanel", "Panel in Message Menu", "Панель в меню сообщения"),
            option("hideReactionEffects", "Reaction Effects", "Анимации реакций")
        ], 3)

        entries.append(.header(id(), tr("CONTEXT MENU ELEMENTS", "МЕНЮ СООБЩЕНИЯ"), 4))
        toggle("menuHistory", "History", "История", 4)
        toggle("menuRead", "Read Message", "Прочитать", 4)
        toggle("menuRepeat", "Repeat Message", "Повторить", 4)

        entries.append(.header(id(), tr("MESSAGE FIELD ELEMENTS", "ЭЛЕМЕНТЫ ПОЛЯ ВВОДА"), 5))
        toggle("fieldAttach", "Attach", "Скрепка", 5)
        toggle("fieldCommands", "Commands", "Команды", 5)
        toggle("fieldTTL", "Self-Destruct Timer", "Таймер исчезновения", 5)
        toggle("fieldEmoji", "Emoji", "Эмодзи", 5)
        toggle("fieldVoice", "Voice", "Голосовое", 5)
        toggle("fieldGift", "Gift", "Подарок", 5)
        toggle("fieldAI", "AI Editor", "AI-редактор", 5)
    }
    return entries
}

private let kittyGramGroups: [String: [String]] = [
    "ghost": KittyGramSettings.ghostFlagKeys,
    "confirm": ["confirmSticker", "confirmGif", "confirmVoice", "confirmRound"],
    "reactions": ["hideReactionsUnderMessages", "hideReactionsPanel", "hideReactionEffects"]
]

private func kittyGramPageTitle(_ page: KittyGramSettingsPage, isRussian: Bool) -> String {
    switch page {
    case .main, .kittyGram:
        return "KittyGram"
    case .filters:
        return isRussian ? "Фильтры" : "Filters"
    case .general:
        return isRussian ? "Общие" : "General"
    case .appearance:
        return isRussian ? "Внешний вид" : "Appearance"
    case .chats:
        return isRussian ? "Чаты" : "Chats"
    }
}

/// Settings that take effect only after the app starts again (drawn images are cached, lists are set up once).
private let kittyGramRestartKeys: Set<String> = ["removeMessageTail", "hideAllChatsTab", "hideNotificationCounters", "disableStories", "avatarCornerPercent"]
/// Set when such a setting changed; the next settings page that closes asks to restart, like AyuGram.
private var kittyGramNeedsRestart = false

private func kittyGramPresentRestartAlert(context: AccountContext) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let isRussian = presentationData.strings.primaryComponent.languageCode == "ru"
    let alert = textAlertController(context: context, title: nil, text: isRussian ? "Чтобы применить некоторые новые настройки, нужен перезапуск. KittyGram закроется, открой его снова. Перезапустить сейчас?" : "You need to restart to apply some of the new settings. KittyGram will close, then open it again. Restart now?", actions: [
        TextAlertAction(type: .genericAction, title: isRussian ? "Позже" : "Later", action: {}),
        TextAlertAction(type: .defaultAction, title: isRussian ? "Перезапустить" : "Restart", action: {
            // iOS does not let an app start itself again: close it, the user opens it from the home screen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                exit(0)
            })
        })
    ])
    context.sharedContext.presentGlobalController(alert, nil)
}

public func kittyGramSettingsController(context: AccountContext) -> ViewController {
    return kittyGramSettingsController(context: context, page: .main)
}

public func kittyGramSettingsController(context: AccountContext, page: KittyGramSettingsPage) -> ViewController {
    let refresh = ValuePromise<Int>(0, ignoreRepeated: false)
    var refreshCounter = 0
    var expanded = Set<String>()
    var currentIconName = context.sharedContext.applicationBindings.getAlternateIconName()

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    func bump() {
        refreshCounter += 1
        refresh.set(refreshCounter)
    }

    let initialPresentationData = context.sharedContext.currentPresentationData.with { $0 }
    let arguments = KittyGramSettingsArguments(context: context, presentationData: initialPresentationData, currentIconName: currentIconName, toggle: { key, value in
        KittyGramSettings.shared.setBool(key, value)
        if kittyGramRestartKeys.contains(key) {
            kittyGramNeedsRestart = true
        }
        bump()
    }, toggleGroup: { groupKey, value in
        for key in kittyGramGroups[groupKey] ?? [] {
            KittyGramSettings.shared.setBool(key, value)
        }
        bump()
    }, toggleExpanded: { groupKey in
        if expanded.contains(groupKey) {
            expanded.remove(groupKey)
        } else {
            expanded.insert(groupKey)
        }
        bump()
    }, openPage: { page in
        pushControllerImpl?(kittyGramSettingsController(context: context, page: page))
    }, openChoice: { key in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let isRussian = presentationData.strings.primaryComponent.languageCode == "ru"
        let settings = KittyGramSettings.shared
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        func add(_ title: String, selected: Bool, _ action: @escaping () -> Void) {
            items.append(ActionSheetButtonItem(title: (selected ? "✓ " : "") + title, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                action()
                bump()
            }))
        }
        switch key {
        case "sendWithoutSound":
            let labels = [isRussian ? "Никогда" : "Never", isRussian ? "В режиме призрака" : "In Ghost Mode", isRussian ? "Всегда" : "Always"]
            for (index, label) in labels.enumerated() {
                add(label, selected: settings.sendWithoutSound == index, {
                    settings.sendWithoutSound = index
                })
            }
        case "deletedMark", "editedMark":
            let isDeleted = key == "deletedMark"
            let current = isDeleted ? settings.deletedMark : settings.editedMark
            let presets = isDeleted ? ["🗑", "🧹", "👻", "❌"] : ["✏️", "✎", "📝"]
            add(isRussian ? "По умолчанию" : "Default", selected: current.isEmpty, {
                if isDeleted {
                    settings.deletedMark = ""
                } else {
                    settings.editedMark = ""
                }
            })
            for preset in presets {
                add(preset, selected: current == preset, {
                    if isDeleted {
                        settings.deletedMark = preset
                    } else {
                        settings.editedMark = preset
                    }
                })
            }
            items.append(ActionSheetButtonItem(title: isRussian ? "Свой текст…" : "Custom Text…", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let prompt = promptController(context: context, text: isDeleted ? (isRussian ? "Метка удаления" : "Deleted Mark") : (isRussian ? "Метка правки" : "Edited Mark"), value: current, placeholder: isRussian ? "Текст или смайлик" : "Text or emoji", characterLimit: 24, apply: { value in
                    guard let value = value else {
                        return
                    }
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if isDeleted {
                        settings.deletedMark = trimmed
                    } else {
                        settings.editedMark = trimmed
                    }
                    bump()
                })
                presentControllerImpl?(prompt)
            }))
        default:
            break
        }
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet)
    }, setSlider: { key, value in
        switch key {
        case "avatarCornerPercent":
            KittyGramSettings.shared.avatarCornerPercent = value * 5
            kittyGramNeedsRestart = true
            bump()
        case "bubbleRadius":
            let radius = Int32(max(0, min(16, value)))
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var current = current
                current.chatBubbleSettings.mainRadius = radius
                current.chatBubbleSettings.auxiliaryRadius = min(8, max(0, radius / 2))
                return current
            }).start()
        default:
            break
        }
    }, setIcon: { icon in
        currentIconName = icon.name
        context.sharedContext.applicationBindings.requestSetAlternateIconName(icon.isDefault ? nil : icon.name, { _ in
        })
        bump()
    }, addPhrase: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let isRussian = presentationData.strings.primaryComponent.languageCode == "ru"
        let prompt = promptController(context: context, text: isRussian ? "Скрывать сообщения со словом" : "Hide messages containing", value: "", placeholder: isRussian ? "Слово или фраза" : "Word or phrase", characterLimit: 100, apply: { value in
            guard let value = value else {
                return
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return
            }
            var phrases = KittyGramSettings.shared.filterPhrases
            if !phrases.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
                phrases.append(trimmed)
                KittyGramSettings.shared.filterPhrases = phrases
            }
            bump()
        })
        presentControllerImpl?(prompt)
    }, removePhrase: { index in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let isRussian = presentationData.strings.primaryComponent.languageCode == "ru"
        let phrases = KittyGramSettings.shared.filterPhrases
        guard index >= 0 && index < phrases.count else {
            return
        }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: (isRussian ? "Удалить «" : "Remove \"") + phrases[index] + (isRussian ? "»" : "\""), color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                var updated = KittyGramSettings.shared.filterPhrases
                if index < updated.count {
                    updated.remove(at: index)
                    KittyGramSettings.shared.filterPhrases = updated
                }
                bump()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet)
    }, openUrl: { url in
        context.sharedContext.applicationBindings.openUrl(url)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        refresh.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, version -> (ItemListControllerState, (ItemListNodeState, Any)) in
        arguments.presentationData = presentationData
        let isRussian = presentationData.strings.primaryComponent.languageCode == "ru"
        let bubbleRadius = Int(presentationData.chatBubbleCorners.mainRadius)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(kittyGramPageTitle(page, isRussian: isRussian)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: kittyGramSettingsEntries(page: page, isRussian: isRussian, expanded: expanded, version: version, currentIconName: currentIconName, bubbleRadius: bubbleRadius), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    controller.didDisappear = { _ in
        if kittyGramNeedsRestart {
            kittyGramNeedsRestart = false
            kittyGramPresentRestartAlert(context: context)
        }
    }
    return controller
}
