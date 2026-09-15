import Foundation

/// Formatters de date fr_FR partagés — évite de reconstruire un `DateFormatter` (coûteux) dans
/// chaque écran, et garde les formats d'affichage cohérents dans toute l'app.
enum AppDateFormat {
    /// "15 sept. 2026"
    static let dayMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    /// "15 sept."
    static let dayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    /// "15 septembre"
    static let dayFullMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    /// "Mardi 15 sept."
    static let weekdayDayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMM"
        return formatter
    }()
}
