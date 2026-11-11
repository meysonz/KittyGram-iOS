import Foundation
import UIKit
import AVFAudio
import UserNotifications
import TelegramCore

/// KittyGram "Work in Background": a sideloaded build gets no push notifications, so while the setting is on the app
/// keeps itself running after it is closed by playing silence (mixed with other audio, so music is not interrupted).
/// While it runs, the connection stays up: new messages show local notifications at once and deletions / edits are
/// saved as they happen.
final class KittyGramBackgroundKeeper {
    static let shared = KittyGramBackgroundKeeper()

    private var player: AVAudioPlayer?
    private var wantsToRun = false
    private var interruptionObserver: NSObjectProtocol?

    var isRunning: Bool {
        return self.player != nil
    }

    private init() {
        self.interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main, using: { [weak self] notification in
            guard let self, self.wantsToRun else {
                return
            }
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
                return
            }
            if type == .ended {
                // A call or another app took the audio session for a while; take it back.
                self.activateSession()
                self.player?.play()
            }
        })
    }

    func update(shouldRun: Bool) {
        self.wantsToRun = shouldRun
        if shouldRun {
            self.start()
        } else {
            self.stop()
        }
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        let _ = try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        let _ = try? session.setActive(true)
    }

    private func start() {
        if self.player != nil {
            return
        }
        self.activateSession()
        guard let player = try? AVAudioPlayer(data: kittyGramSilentWave()) else {
            return
        }
        player.numberOfLoops = -1
        player.volume = 0.0
        player.prepareToPlay()
        if player.play() {
            self.player = player
        }
    }

    private func stop() {
        guard let player = self.player else {
            return
        }
        self.player = nil
        player.stop()
    }
}

/// One second of 16-bit mono silence as a WAV file.
private func kittyGramSilentWave() -> Data {
    let sampleRate: UInt32 = 8000
    let sampleCount: UInt32 = sampleRate
    let dataSize: UInt32 = sampleCount * 2
    var data = Data()
    func append(_ string: String) {
        data.append(contentsOf: Array(string.utf8))
    }
    func append32(_ value: UInt32) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    func append16(_ value: UInt16) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    append("RIFF")
    append32(36 + dataSize)
    append("WAVE")
    append("fmt ")
    append32(16)
    append16(1)
    append16(1)
    append32(sampleRate)
    append32(sampleRate * 2)
    append16(2)
    append16(16)
    append("data")
    append32(dataSize)
    data.append(Data(count: Int(dataSize)))
    return data
}

/// Shows a local notification for a message that arrived while the app is not on screen (KittyGram has no push).
func kittyGramPostLocalNotification(identifier: String, threadIdentifier: String, title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.threadIdentifier = threadIdentifier
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
}
