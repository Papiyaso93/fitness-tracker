import Foundation
import SwiftData

enum HeadlineGoalType: String, Codable, CaseIterable {
    case masseGrasse = "Masse grasse"
    case poids = "Poids"
    case vo2max = "VO2max"

    var unit: String {
        switch self {
        case .masseGrasse: return "%"
        case .poids: return "kg"
        case .vo2max: return "ml/kg/min"
        }
    }
}

enum MetricSource: String, Codable {
    case healthKit = "Apple Santé"
    case manual = "Saisie manuelle"
}

@Model
final class MetricEntry {
    var id: UUID
    var type: HeadlineGoalType
    var value: Double
    var date: Date
    var source: MetricSource

    init(type: HeadlineGoalType, value: Double, date: Date = .now, source: MetricSource = .manual) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.date = date
        self.source = source
    }
}
