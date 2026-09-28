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

extension Date {
    /// Compare au niveau du jour calendaire local plutôt que de l'instant exact — une date importée
    /// (JSON généré hors app, ex: programme reçu de Claude) encode souvent minuit UTC, ce qui la
    /// décale de quelques heures par rapport à `Calendar.current.startOfDay(for: .now)` selon le
    /// fuseau horaire, et fait paraître à tort un programme/cycle "pas encore commencé" le jour même.
    func isOnOrBefore(_ other: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: self) <= calendar.startOfDay(for: other)
    }

    func isOnOrAfter(_ other: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: self) >= calendar.startOfDay(for: other)
    }

    func isStrictlyAfter(_ other: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: self) > calendar.startOfDay(for: other)
    }
}
