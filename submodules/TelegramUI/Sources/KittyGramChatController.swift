import Foundation
import UIKit
import Display
import TelegramCore
import PresentationDataUtils

extension ChatControllerImpl {
    /// KittyGram "Send Confirmations": asks before a sticker or GIF goes out.
    func kittyGramConfirmSend(text: String, confirm: @escaping () -> Void) {
        let isRussian = self.presentationData.strings.primaryComponent.languageCode == "ru"
        let alert = textAlertController(context: self.context, title: nil, text: text, actions: [
            TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .defaultAction, title: isRussian ? "Отправить" : "Send", action: confirm)
        ])
        self.present(alert, in: .window(.root))
    }
}
