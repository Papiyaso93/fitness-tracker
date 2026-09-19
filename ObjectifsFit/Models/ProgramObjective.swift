import Foundation
import SwiftData

/// Indicateur chiffrable disponible pour un objectif de programme — réunit les métriques déjà
/// suivies ailleurs dans l'app (masse grasse/poids/VO2max + mensurations), sans les recoupler au
/// Cycle 1 existant.
enum ObjectiveMetricType: String, Codable, CaseIterable, Identifiable {
    case masseGrasse = "Masse grasse"
    case poids = "Poids"
    case vo2max = "VO2max"
    case tourDeTaille = "Tour de taille"
    case tourDeHanches = "Tour de hanches"
    case tourDEpaules = "Tour d'épaules"
    case tourDeBiceps = "Tour de biceps"
    case tourDeMollet = "Tour de mollet"
    case tourDePecs = "Tour de pecs"
    case tourDeCuisse = "Tour de cuisse"
    case nombreDePas = "Nombre de pas"
    case autre = "Autre"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .masseGrasse: return "%"
        case .poids: return "kg"
        case .vo2max: return "ml/kg/min"
        case .nombreDePas: return "pas/jour"
        case .autre: return ""
        default: return "cm"
        }
    }
}

enum ObjectiveMode: String, Codable, CaseIterable, Identifiable {
    case progression = "Progression"
    case maintien = "Maintien"

    var id: String { rawValue }
}

enum ObjectiveCategory: String, Codable, Identifiable {
    case principal = "Principal"
    case indicateur = "Indicateur"

    var id: String { rawValue }
}

/// Un objectif chiffré ou texte libre — soit un objectif/indicateur de programme (avec
/// principal/indicateur distincts), soit un jalon de cycle (liste plate, `category` non utilisée).
@Model
final class ProgramObjective {
    var id: UUID
    var category: ObjectiveCategory
    var isMeasurable: Bool
    var freeText: String?
    private var metricTypeRaw: String?
    var customMetricName: String?
    var customUnit: String?
    var mode: ObjectiveMode?
    var startValue: Double?
    var targetValue: Double?
    var order: Int

    var program: TrainingProgram?
    var cycle: Cycle?

    var metricType: ObjectiveMetricType? {
        get { metricTypeRaw.flatMap(ObjectiveMetricType.init(rawValue:)) }
        set { metricTypeRaw = newValue?.rawValue }
    }

    private var metricName: String {
        metricType == .autre ? (customMetricName ?? "Autre") : (metricType?.rawValue ?? "")
    }

    private var metricUnit: String {
        metricType == .autre ? (customUnit ?? "") : (metricType?.unit ?? "")
    }

    init(
        category: ObjectiveCategory,
        isMeasurable: Bool,
        freeText: String? = nil,
        metricType: ObjectiveMetricType? = nil,
        customMetricName: String? = nil,
        customUnit: String? = nil,
        mode: ObjectiveMode? = nil,
        startValue: Double? = nil,
        targetValue: Double? = nil,
        order: Int = 0
    ) {
        self.id = UUID()
        self.category = category
        self.isMeasurable = isMeasurable
        self.freeText = freeText
        self.metricTypeRaw = metricType?.rawValue
        self.customMetricName = customMetricName
        self.customUnit = customUnit
        self.mode = mode
        self.startValue = startValue
        self.targetValue = targetValue
        self.order = order
    }

    /// Nom seul (sans la valeur cible) — pour un affichage compact façon badge/tag.
    var name: String {
        isMeasurable ? metricName : (freeText ?? "")
    }

    /// Résumé lisible : "Masse grasse : Passer de 20% à 15%", "Pecs : maintenir 102cm", ou le texte libre.
    var summary: String {
        guard isMeasurable, let mode, let targetValue else {
            return freeText ?? ""
        }
        switch mode {
        case .progression:
            let start = startValue.map { "\($0.formatted())\(metricUnit)" } ?? "?"
            return "\(metricName) : Passer de \(start) à \(targetValue.formatted())\(metricUnit)"
        case .maintien:
            return "\(metricName) : maintenir \(targetValue.formatted())\(metricUnit)"
        }
    }
}
