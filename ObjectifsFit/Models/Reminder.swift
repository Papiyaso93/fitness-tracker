import Foundation
import SwiftData

enum ReminderFrequency: String, Codable, CaseIterable {
    case quotidien = "Quotidien"
    case hebdomadaire = "Hebdomadaire"

    var id: String { rawValue }
}

/// Rappel local paramétrable par l'utilisateur (heure + message), en nombre illimité — remplace
/// l'ancien rappel transit unique codé en dur.
@Model
final class Reminder {
    var id: UUID
    var title: String
    var message: String
    var hour: Int
    var minute: Int
    var frequency: ReminderFrequency = ReminderFrequency.quotidien
    /// Convention `Calendar` (1=dimanche...7=samedi, cf. `Weekday`) — utilisé seulement quand
    /// `frequency == .hebdomadaire`.
    var weekday: Int?

    init(title: String, message: String, hour: Int, minute: Int, frequency: ReminderFrequency = .quotidien, weekday: Int? = nil) {
        self.id = UUID()
        self.title = title
        self.message = message
        self.hour = hour
        self.minute = minute
        self.frequency = frequency
        self.weekday = weekday
    }

    var timeLabel: String {
        String(format: "%dh%02d", hour, minute)
    }

    /// "21h00" ou "Dimanche 21h00" — utilisé dans la liste des rappels pour distinguer d'un coup
    /// d'œil un rappel quotidien d'un rappel hebdomadaire.
    var scheduleLabel: String {
        switch frequency {
        case .quotidien: return timeLabel
        case .hebdomadaire: return "\(weekday.map(Weekday.label(for:)) ?? "") \(timeLabel)"
        }
    }
}
