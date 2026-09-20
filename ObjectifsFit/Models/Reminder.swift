import Foundation
import SwiftData

/// Rappel local paramétrable par l'utilisateur (heure + message), en nombre illimité — remplace
/// l'ancien rappel transit unique codé en dur.
@Model
final class Reminder {
    var id: UUID
    var title: String
    var message: String
    var hour: Int
    var minute: Int

    init(title: String, message: String, hour: Int, minute: Int) {
        self.id = UUID()
        self.title = title
        self.message = message
        self.hour = hour
        self.minute = minute
    }

    var timeLabel: String {
        String(format: "%dh%02d", hour, minute)
    }
}
