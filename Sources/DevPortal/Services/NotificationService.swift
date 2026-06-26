import Foundation
import UserNotifications

final class NotificationService: @unchecked Sendable {
  static let shared = NotificationService()

  private init() {}

  func requestAuthorization() async -> Bool {
    await withCheckedContinuation { continuation in
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
        continuation.resume(returning: granted)
      }
    }
  }

  func post(identifier: String, title: String, body: String) async {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: nil
    )

    await withCheckedContinuation { continuation in
      UNUserNotificationCenter.current().add(request) { _ in
        continuation.resume()
      }
    }
  }
}
