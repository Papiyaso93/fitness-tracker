import Foundation
import UserNotifications

/// Rappel local en fin de journée pour renseigner le transit si oublié.
enum NotificationManager {
    static let transitReminderId = "transit-reminder"

    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleTransitReminder(hour: Int = 21, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [transitReminderId])

        let content = UNMutableNotificationContent()
        content.title = "Transit du jour"
        content.body = "Tu n'as pas encore renseigné ton transit aujourd'hui."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: transitReminderId, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelTransitReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [transitReminderId])
    }
}
