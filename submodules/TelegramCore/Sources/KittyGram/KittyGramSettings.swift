import Foundation

/// KittyGram feature switches. Stored in UserDefaults so every module (TelegramCore, TelegramUI, extensions) can read them
/// synchronously without going through Postbox. Defaults are chosen so a fresh install behaves exactly like Telegram.
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

    // MARK: Ghost mode (each flag hides one thing from other people)

    /// Do not tell the server (and the sender) that messages were read.
    public var hideRead: Bool {
        get { return self.read("hideRead", false) }
        set { self.write("hideRead", newValue) }
    }

    /// Do not report story views.
    public var hideStoryViews: Bool {
        get { return self.read("hideStoryViews", false) }
        set { self.write("hideStoryViews", newValue) }
    }

    /// Never send the "online" status.
    public var hideOnline: Bool {
        get { return self.read("hideOnline", false) }
        set { self.write("hideOnline", newValue) }
    }

    /// Never send "typing" and upload progress activities.
    public var hideTyping: Bool {
        get { return self.read("hideTyping", false) }
        set { self.write("hideTyping", newValue) }
    }

    /// Send an "offline" status right after going online.
    public var offlineAfterOnline: Bool {
        get { return self.read("offlineAfterOnline", false) }
        set { self.write("offlineAfterOnline", newValue) }
    }

    public static let ghostFlagCount = 5

    public var activeGhostFlagCount: Int {
        let flags = [self.hideRead, self.hideStoryViews, self.hideOnline, self.hideTyping, self.offlineAfterOnline]
        return flags.filter { $0 }.count
    }

    /// Master switch: turns every ghost flag on or off together.
    public var ghostMode: Bool {
        get { return self.activeGhostFlagCount == KittyGramSettings.ghostFlagCount }
        set {
            self.defaults.set(newValue, forKey: "kittygram.hideRead")
            self.defaults.set(newValue, forKey: "kittygram.hideStoryViews")
            self.defaults.set(newValue, forKey: "kittygram.hideOnline")
            self.defaults.set(newValue, forKey: "kittygram.hideTyping")
            self.defaults.set(newValue, forKey: "kittygram.offlineAfterOnline")
            NotificationCenter.default.post(name: KittyGramSettings.didChangeNotification, object: nil)
        }
    }

    /// Mark a chat as read when the user sends a message or taps a reaction.
    public var readOnInteract: Bool {
        get { return self.read("readOnInteract", true) }
        set { self.write("readOnInteract", newValue) }
    }

    /// Show the "Enter Ghost Mode" quick action on the app icon.
    public var homeShortcut: Bool {
        get { return self.read("homeShortcut", true) }
        set { self.write("homeShortcut", newValue) }
    }

    // MARK: Saved messages

    public var saveDeleted: Bool {
        get { return self.read("saveDeleted", true) }
        set { self.write("saveDeleted", newValue) }
    }

    public var saveEdits: Bool {
        get { return self.read("saveEdits", true) }
        set { self.write("saveEdits", newValue) }
    }

    public var saveInBots: Bool {
        get { return self.read("saveInBots", false) }
        set { self.write("saveInBots", newValue) }
    }

    // MARK: General

    public var showPeerId: Bool {
        get { return self.read("showPeerId", true) }
        set { self.write("showPeerId", newValue) }
    }

    public var showSeconds: Bool {
        get { return self.read("showSeconds", false) }
        set { self.write("showSeconds", newValue) }
    }
}
