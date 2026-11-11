import Foundation
import UIKit
import Display
import AppBundle

/// Put in front of a deleted message's date text when "Replace with Icons" is on; the status node draws a trash icon.
public let kittyGramDeletedIconMarker = "\u{E001}"

/// Trash and/or pencil icons, tinted like the message time, side by side.
func kittyGramMarkIcons(deleted: Bool, edited: Bool, color: UIColor, fontSize: CGFloat) -> UIImage? {
    var names: [String] = []
    if deleted {
        names.append("Chat/Context Menu/Delete")
    }
    if edited {
        names.append("Chat/Context Menu/Edit")
    }
    if names.isEmpty {
        return nil
    }
    let side = max(10.0, floor(fontSize * 1.15))
    let spacing: CGFloat = 1.0
    let size = CGSize(width: CGFloat(names.count) * side + CGFloat(names.count - 1) * spacing, height: side)
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        UIGraphicsPushContext(context)
        for (index, name) in names.enumerated() {
            if let image = generateTintedImage(image: UIImage(bundleImageName: name), color: color) {
                image.draw(in: CGRect(x: CGFloat(index) * (side + spacing), y: 0.0, width: side, height: side))
            }
        }
        UIGraphicsPopContext()
    })
}

/// Two icons in a row, vertically centred.
func kittyGramJoinImages(_ first: UIImage, _ second: UIImage) -> UIImage? {
    let spacing: CGFloat = 3.0
    let size = CGSize(width: first.size.width + spacing + second.size.width, height: max(first.size.height, second.size.height))
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        UIGraphicsPushContext(context)
        first.draw(in: CGRect(x: 0.0, y: floor((size.height - first.size.height) / 2.0), width: first.size.width, height: first.size.height))
        second.draw(in: CGRect(x: first.size.width + spacing, y: floor((size.height - second.size.height) / 2.0), width: second.size.width, height: second.size.height))
        UIGraphicsPopContext()
    })
}
