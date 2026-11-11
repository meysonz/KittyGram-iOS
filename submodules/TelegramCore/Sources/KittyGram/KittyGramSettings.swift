import Foundation

/// KittyGram feature switches. Stored in UserDefaults so every module (TelegramCore, TelegramUI, extensions) can read them
/// synchronously without going through Postbox. Defaults are chosen so a fresh install behaves like Telegram, except for
/// the saving features KittyGram exists for.
public final class KittyGramSettings: @unchecked Sendable {
    public static let shared = KittyGramSettings()
    public static let didChangeNotification = Notification.Name("KittyGramSettingsDidChange")

    private let defaults: UserDefaults

    private init() {
        self.defaults = UserDefaults.standard
    }

    private func read(_ key: String, _ fallback: Bool) -> Bool {
        let fullKey = "kittygram." + key
        if self.defaults.object(forKey: fullKey) == nil {
            return fallback
        }
        return self.defaults.bool(forKey: fullKey)
    }

    private func write(_ key: String, _ value: Bool) {
        self.defaults.set(value, forKey: "kittygram." + key)
        NotificationCenter.default.post(name: KittyGramSettings.didChangeNotification, object: nil)
    }

    private func readInt(_ key: String, _ fallback: Int) -> Int {
        let fullKey = "kittygram." + key
        if self.defaults.object(forKey: fullKey) == nil {
            return fallback
        }
        return self.defaults.integer(forKey: fullKey)
    }

    private func writeInt(_ key: String, _ value: Int) {
        self.defaults.set(value, forKey: "kittygram." + key)
        NotificationCenter.default.post(name: KittyGramSettings.didChangeNotification, object: nil)
    }

    private func readString(_ key: String) -> String {
        return self.defaults.string(forKey: "kittygram." + key) ?? ""
    }

    private func writeString(_ key: String, _ value: String) {
        self.defaults.set(value, forKey: "kittygram." + key)
        NotificationCenter.default.post(name: KittyGramSettings.didChangeNotification, object: nil)
    }

    /// Generic access for the settings screens: every boolean switch below is also reachable by its key.
    public func bool(_ key: String) -> Bool {
        return self.read(key, KittyGramSettings.boolDefaults[key] ?? false)
    }

    public func setBool(_ key: String, _ value: Bool) {
        self.write(key, value)
    }

    private static let boolDefaults: [String: Bool] = [
        "hideRead": false,
        "hideStoryViews": false,
        "hideOnline": false,
        "hideTyping": false,
        "offlineAfterOnline": false,
        "readOnInteract": true,
        "storyGhostAlert": true,
        "saveDeleted": true,
        "saveEdits": true,
        "saveInBots": false,
        "keepSelfDestructing": true,
        "selfDestructScreenshots": true,
        "disableAds": false,
        "backgroundMode": false,
        "notificationText": true,
        "confirmSticker": false,
        "confirmGif": false,
        "confirmVoice": false,
        "confirmRound": false,
        "disableLinkWarning": false,
        "disableStories": false,
        "disableSimilarChannels": false,
        "showPeerId": true,
        "hideNotificationCounters": false,
        "hideAllChatsTab": false,
        "disableCustomBackgrounds": false,
        "replaceMarksWithIcons": false,
        "removeMessageTail": false,
        "hideSideShareButton": false,
        "disableColorfulReplies": false,
        "translucentDeleted": false,
        "showSeconds": false,
        "disableGreetingSticker": false,
        "hideReactionsUnderMessages": false,
        "hideReactionsPanel": false,
        "hideReactionEffects": false,
        "menuHistory": true,
        "menuRead": true,
        "menuRepeat": true,
        "fieldAttach": true,
        "fieldCommands": true,
        "fieldTTL": true,
        "fieldEmoji": true,
        "fieldVoice": true,
        "fieldGift": true,
        "fieldAI": true
    ]

    // MARK: Ghost mode (each flag hides one thing from other people)

    /// Do not tell the server (and the sender) that messages were read.
    public var hideRead: Bool {
        get { return self.bool("hideRead") }
        set { self.write("hideRead", newValue) }
    }

    /// Do not report story views.
    public var hideStoryViews: Bool {
        get { return self.bool("hideStoryViews") }
        set { self.write("hideStoryViews", newValue) }
    }

    /// Never send the "online" status.
    public var hideOnline: Bool {
        get { return self.bool("hideOnline") }
        set { self.write("hideOnline", newValue) }
    }

    /// Never send "typing" and upload progress activities.
    public var hideTyping: Bool {
        get { return self.bool("hideTyping") }
        set { self.write("hideTyping", newValue) }
    }

    /// Send an "offline" status right after going online.
    public var offlineAfterOnline: Bool {
        get { return self.bool("offlineAfterOnline") }
        set { self.write("offlineAfterOnline", newValue) }
    }

    public static let ghostFlagKeys = ["hideRead", "hideStoryViews", "hideOnline", "hideTyping", "offlineAfterOnline"]
    public static let ghostFlagCount = 5

    public var activeGhostFlagCount: Int {
        return KittyGramSettings.ghostFlagKeys.filter { self.bool($0) }.count
    }

    /// Master switch: turns every ghost flag on or off together.
    public var ghostMode: Bool {
        get { return self.activeGhostFlagCount == KittyGramSettings.ghostFlagCount }
        set {
            for key in KittyGramSettings.ghostFlagKeys {
                self.defaults.set(newValue, forKey: "kittygram." + key)
            }
            NotificationCenter.default.post(name: KittyGramSettings.didChangeNotification, object: nil)
        }
    }

    /// Mark a chat as read when the user sends a message or reacts there.
    public var readOnInteract: Bool {
        get { return self.bool("readOnInteract") }
        set { self.write("readOnInteract", newValue) }
    }

    /// Ask to turn ghost mode on before a story opens while story views are reported.
    public var storyGhostAlert: Bool {
        get { return self.bool("storyGhostAlert") }
        set { self.write("storyGhostAlert", newValue) }
    }

    private let storyHoldLock = NSLock()
    private var _storyViewsOnHold = false

    /// Set while the "turn ghost mode on?" question before a story is open: no story view is reported meanwhile.
    /// Not stored; it lasts only while the story viewer is on screen.
    public var storyViewsOnHold: Bool {
        get {
            self.storyHoldLock.lock()
            defer { self.storyHoldLock.unlock() }
            return self._storyViewsOnHold
        }
        set {
            self.storyHoldLock.lock()
            self._storyViewsOnHold = newValue
            self.storyHoldLock.unlock()
        }
    }

    /// Story views are not reported now: hidden by ghost mode, or held while the user decides.
    public var storyViewsHidden: Bool {
        return self.hideStoryViews || self.storyViewsOnHold
    }

    /// 0 = never, 1 = only in ghost mode, 2 = always.
    public var sendWithoutSound: Int {
        get { return self.readInt("sendWithoutSound", 0) }
        set { self.writeInt("sendWithoutSound", newValue) }
    }

    // MARK: Saving

    public var saveDeleted: Bool {
        get { return self.bool("saveDeleted") }
        set { self.write("saveDeleted", newValue) }
    }

    public var saveEdits: Bool {
        get { return self.bool("saveEdits") }
        set { self.write("saveEdits", newValue) }
    }

    public var saveInBots: Bool {
        get { return self.bool("saveInBots") }
        set { self.write("saveInBots", newValue) }
    }

    /// View self-destructing (timer / view-once) photos, videos and voice messages without starting their timer and
    /// without telling the sender they were opened; they can also be saved and forwarded (as a copy).
    public var keepSelfDestructing: Bool {
        get { return self.bool("keepSelfDestructing") }
        set { self.write("keepSelfDestructing", newValue) }
    }

    /// Allow screenshots of self-destructing media and never send "took a screenshot".
    public var selfDestructScreenshots: Bool {
        get { return self.bool("selfDestructScreenshots") }
        set { self.write("selfDestructScreenshots", newValue) }
    }

    /// Do not load sponsored messages.
    public var disableAds: Bool {
        get { return self.bool("disableAds") }
        set { self.write("disableAds", newValue) }
    }

    // MARK: General

    public var backgroundMode: Bool {
        get { return self.bool("backgroundMode") }
        set { self.write("backgroundMode", newValue) }
    }

    public var notificationText: Bool {
        get { return self.bool("notificationText") }
        set { self.write("notificationText", newValue) }
    }

    public var disableLinkWarning: Bool {
        get { return self.bool("disableLinkWarning") }
        set { self.write("disableLinkWarning", newValue) }
    }

    public var disableStories: Bool {
        get { return self.bool("disableStories") }
        set { self.write("disableStories", newValue) }
    }

    public var disableSimilarChannels: Bool {
        get { return self.bool("disableSimilarChannels") }
        set { self.write("disableSimilarChannels", newValue) }
    }

    public var showPeerId: Bool {
        get { return self.bool("showPeerId") }
        set { self.write("showPeerId", newValue) }
    }

    // MARK: Appearance

    /// Avatar corner radius as a fraction of the avatar size in percent: 50 is a circle (Telegram's look), 0 a square.
    public var avatarCornerPercent: Int {
        get { return self.readInt("avatarCornerPercent", 50) }
        set { self.writeInt("avatarCornerPercent", max(0, min(50, newValue))) }
    }

    public var hideNotificationCounters: Bool {
        get { return self.bool("hideNotificationCounters") }
        set { self.write("hideNotificationCounters", newValue) }
    }

    public var hideAllChatsTab: Bool {
        get { return self.bool("hideAllChatsTab") }
        set { self.write("hideAllChatsTab", newValue) }
    }

    public var disableCustomBackgrounds: Bool {
        get { return self.bool("disableCustomBackgrounds") }
        set { self.write("disableCustomBackgrounds", newValue) }
    }

    // MARK: Chats

    public var replaceMarksWithIcons: Bool {
        get { return self.bool("replaceMarksWithIcons") }
        set { self.write("replaceMarksWithIcons", newValue) }
    }

    public var removeMessageTail: Bool {
        get { return self.bool("removeMessageTail") }
        set { self.write("removeMessageTail", newValue) }
    }

    public var hideSideShareButton: Bool {
        get { return self.bool("hideSideShareButton") }
        set { self.write("hideSideShareButton", newValue) }
    }

    public var disableColorfulReplies: Bool {
        get { return self.bool("disableColorfulReplies") }
        set { self.write("disableColorfulReplies", newValue) }
    }

    public var translucentDeleted: Bool {
        get { return self.bool("translucentDeleted") }
        set { self.write("translucentDeleted", newValue) }
    }

    /// Text shown next to the time of a deleted message; empty means the default ("deleted").
    public var deletedMark: String {
        get { return self.readString("deletedMark") }
        set { self.writeString("deletedMark", newValue) }
    }

    /// Text shown next to the time of an edited message; empty means Telegram's own "edited".
    public var editedMark: String {
        get { return self.readString("editedMark") }
        set { self.writeString("editedMark", newValue) }
    }

    public var showSeconds: Bool {
        get { return self.bool("showSeconds") }
        set { self.write("showSeconds", newValue) }
    }

    public var disableGreetingSticker: Bool {
        get { return self.bool("disableGreetingSticker") }
        set { self.write("disableGreetingSticker", newValue) }
    }

    public var hideReactionsUnderMessages: Bool {
        get { return self.bool("hideReactionsUnderMessages") }
        set { self.write("hideReactionsUnderMessages", newValue) }
    }

    public var hideReactionsPanel: Bool {
        get { return self.bool("hideReactionsPanel") }
        set { self.write("hideReactionsPanel", newValue) }
    }

    public var hideReactionEffects: Bool {
        get { return self.bool("hideReactionEffects") }
        set { self.write("hideReactionEffects", newValue) }
    }

    // MARK: Filters

    /// Messages whose text contains one of these phrases (case-insensitive) are hidden from chats.
    public var filterPhrases: [String] {
        get { return self.defaults.stringArray(forKey: "kittygram.filterPhrases") ?? [] }
        set {
            self.defaults.set(newValue, forKey: "kittygram.filterPhrases")
            NotificationCenter.default.post(name: KittyGramSettings.didChangeNotification, object: nil)
        }
    }

    public func isFiltered(text: String) -> Bool {
        if text.isEmpty {
            return false
        }
        let phrases = self.filterPhrases
        if phrases.isEmpty {
            return false
        }
        let lowercased = text.lowercased()
        for phrase in phrases {
            let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !trimmed.isEmpty && lowercased.contains(trimmed) {
                return true
            }
        }
        return false
    }
}
