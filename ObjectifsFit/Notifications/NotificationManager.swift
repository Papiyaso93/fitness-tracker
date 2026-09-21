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

    /// Annule toute notification programmée qui ne correspond plus à un `Reminder` existant —
    /// une réinstallation par Xcode ("Replace") écrase les données de l'app mais pas les
    /// notifications déjà programmées côté iOS, qui peuvent donc devenir orphelines (rappel
    /// supprimé entre deux installs, ou seed par défaut qui a changé).
    static func syncPending(with reminders: [Reminder]) {
        let center = UNUserNotificationCenter.current()
        let validIdentifiers = Set(reminders.map { $0.id.uuidString })
        center.getPendingNotificationRequests { requests in
            let staleIdentifiers = requests.map(\.identifier).filter { !validIdentifiers.contains($0) }
            guard !staleIdentifiers.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
        }
    }
}
