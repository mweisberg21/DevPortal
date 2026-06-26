import AppKit
import Foundation

enum Confirmations {
  @MainActor
  static func confirmDestructive(title: String, message: String, actionTitle: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: actionTitle)
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn
  }
}
