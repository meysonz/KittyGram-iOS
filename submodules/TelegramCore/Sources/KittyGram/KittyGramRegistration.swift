import Foundation

/// Telegram does not publish when an account was registered, but user ids grow with time. This estimates the month
/// by interpolating between a few well-known (id, date) points. The result is approximate and is labelled as such in the UI.
private let kittyGramRegistrationAnchors: [(id: Int64, timestamp: TimeInterval)] = [
    (2768409, 1383264000),
    (7679610, 1388448000),
    (11538514, 1391212800),
    (44634663, 1399334400),
    (63263518, 1414454400),
    (101260938, 1425600000),
    (222021233, 1465344000),
    (294851037, 1479600000),
    (400169472, 1501459200),
    (616816630, 1529625600),
    (796147074, 1541376000),
    (1693744373, 1615766400),
    (5000000000, 1638316800),
    (6000000000, 1659312000),
    (7000000000, 1693526400)
]

public func kittyGramEstimatedRegistrationText(userId: Int64, languageCode: String) -> String? {
    if userId <= 0 {
        return nil
    }
    let anchors = kittyGramRegistrationAnchors
    guard let first = anchors.first, let last = anchors.last else {
        return nil
    }

    var timestamp: TimeInterval
    if userId <= first.id {
        timestamp = first.timestamp
    } else if userId >= last.id {
        timestamp = min(last.timestamp + Double(userId - last.id) * 0.0000002, Date().timeIntervalSince1970)
    } else {
        timestamp = last.timestamp
        var index = 1
        while index < anchors.count {
            let lower = anchors[index - 1]
            let upper = anchors[index]
            if userId <= upper.id {
                let fraction = Double(userId - lower.id) / Double(upper.id - lower.id)
                timestamp = lower.timestamp + fraction * (upper.timestamp - lower.timestamp)
                break
            }
            index += 1
        }
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: languageCode == "ru" ? "ru_RU" : "en_US")
    formatter.dateFormat = "LLLL yyyy"
    let text = formatter.string(from: Date(timeIntervalSince1970: timestamp))
    guard let firstCharacter = text.first else {
        return nil
    }
    return String(firstCharacter).uppercased() + String(text.dropFirst())
}
