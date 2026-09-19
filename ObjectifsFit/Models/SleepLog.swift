import Foundation
import SwiftData

enum EnergyLevel: String, Codable, CaseIterable {
    case epuise = "Épuisé"
    case fatigue = "Fatigué"
    case normal = "Normal"
    case enForme = "En forme"
    case pleinEnergie = "Plein d'énergie"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .epuise: return "😴 Épuisé"
        case .fatigue: return "🥱 Fatigué"
        case .normal: return "😐 Normal"
        case .enForme: return "🙂 En forme"
        case .pleinEnergie: return "⚡ Plein d'énergie"
        }
    }
}

enum StomachState: String, Codable, CaseIterable {
    case ballonne = "Ballonné"
    case inconfortable = "Inconfortable"
    case neutre = "Neutre"
    case confortable = "Confortable"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ballonne: return "🔴 Ballonné"
        case .inconfortable: return "🟠 Inconfortable"
        case .neutre: return "🟡 Neutre"
        case .confortable: return "🟢 Confortable"
        }
    }
}

/// Un enregistrement par jour, rempli en deux temps (réveil le matin, coucher le soir) — pas une
/// liste libre comme Repas/Transit, puisqu'il n'y a par nature qu'un réveil et qu'un coucher par jour.
@Model
final class SleepLog {
    var id: UUID
    /// Toujours normalisée à minuit (`Calendar.startOfDay`) — sert de clé d'unicité par jour.
    var day: Date

    var wakeTime: Date?
    var wakeEnergy: EnergyLevel?
    var wakeStomach: StomachState?

    var bedTime: Date?
    var bedEnergy: EnergyLevel?
    var bedStomach: StomachState?

    init(day: Date) {
        self.id = UUID()
        self.day = day
    }
}
