import Foundation

/// Jours de la semaine dans l'ordre d'affichage de l'app (Lundi→Dimanche), avec la convention
/// `Calendar` (1=dimanche...7=samedi) utilisée par `CycleSession.weekday`. Source unique pour
/// éviter que cette liste soit recopiée (et potentiellement mal transcrite) à chaque écran.
enum Weekday {
    static let ordered: [(weekday: Int, label: String)] = [
        (2, "Lundi"), (3, "Mardi"), (4, "Mercredi"), (5, "Jeudi"), (6, "Vendredi"), (7, "Samedi"), (1, "Dimanche")
    ]

    static func label(for weekday: Int) -> String {
        ordered.first { $0.weekday == weekday }?.label ?? ""
    }
}
