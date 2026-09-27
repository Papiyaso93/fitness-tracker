import Foundation
import SwiftData

/// Niveau de forme ressenti sur la semaine écoulée — volontairement à 3 niveaux (pas l'échelle à 6
/// niveaux de `SensationLevel`, trop fine pour un ressenti hebdomadaire global).
enum WeeklyFormLevel: String, Codable, CaseIterable {
    case bien = "Ça va"
    case fatigue = "Fatigué"
    case dur = "Dur"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bien: return "checkmark.circle.fill"
        case .fatigue: return "exclamationmark.circle.fill"
        case .dur: return "xmark.octagon.fill"
        }
    }
}

/// Bilan hebdomadaire modulaire (dimanche) — chaque champ est optionnel et rempli seulement si le
/// module correspondant a été choisi lors de la saisie, pour rester rapide à faire chaque semaine
/// plutôt que de forcer un formulaire complet.
@Model
final class WeeklyCheckIn {
    var id: UUID
    /// Dimanche de la semaine concernée, normalisé à minuit — clé d'unicité par semaine.
    var weekDate: Date
    var formLevel: WeeklyFormLevel?
    var runningVolumeKm: Double?
    var averageStepsPerDay: Int?
    var note: String?

    init(weekDate: Date) {
        self.id = UUID()
        self.weekDate = weekDate
    }
}
