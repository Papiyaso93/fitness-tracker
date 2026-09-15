import Foundation
import SwiftData

/// Échelle de Bristol (1 = constipation sévère, 7 = diarrhée), pour permettre des stats/analyses
/// de régularité plus tard (corrélation avec nutrition, masse grasse, etc.).
enum BristolType: Int, Codable, CaseIterable, Identifiable {
    case type1 = 1, type2, type3, type4, type5, type6, type7

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .type1: return "Type 1 — Morceaux durs"
        case .type2: return "Type 2 — Saucisse bosselée"
        case .type3: return "Type 3 — Saucisse craquelée"
        case .type4: return "Type 4 — Lisse et molle"
        case .type5: return "Type 5 — Morceaux mous"
        case .type6: return "Type 6 — Pâteux"
        case .type7: return "Type 7 — Liquide"
        }
    }

    var category: String {
        switch self {
        case .type1, .type2: return "Constipation"
        case .type3, .type4: return "Normal"
        case .type5, .type6, .type7: return "Transit rapide"
        }
    }
}

@Model
final class TransitLog {
    var id: UUID
    var dateTime: Date
    var bristolType: BristolType

    init(dateTime: Date = .now, bristolType: BristolType) {
        self.id = UUID()
        self.dateTime = dateTime
        self.bristolType = bristolType
    }
}
