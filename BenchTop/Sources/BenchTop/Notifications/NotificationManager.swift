import Foundation
import UserNotifications

protocol NotificationManaging {
    func requestAuthorization()
    func notify(title: String, body: String)
}

/// Thin wrapper around UNUserNotificationCenter for local alerts (job done,
/// job failed, GPU throttling, etc). No push server involved — the agent and
/// app are both on the same LAN, so everything the app needs to know it
/// learns by polling and raises locally.
final class NotificationManager: NotificationManaging {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
