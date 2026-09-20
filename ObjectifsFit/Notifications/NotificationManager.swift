import Foundation
import UserNotifications

/// Rappels locaux paramétrables — un par `Reminder`, identifié par son UUID pour pouvoir le
/// reprogrammer/annuler individuellement quand l'utilisateur le modifie ou le supprime.
enum NotificationManager {
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func schedule(_ reminder: Reminder) {
        let center = UNUserNotificationCenter.current()
        let identifier = reminder.id.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = reminder.hour
        dateComponents.minute = reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancel(_ reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
    }
}
