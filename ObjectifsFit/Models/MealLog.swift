import Foundation
import SwiftData

enum MealSensation: String, Codable, CaseIterable {
    case encoreFaim = "Encore faim"
    case rassasie80 = "~80% rassasié"
    case rassasiePile = "Rassasié pile"
    case tropMange = "Trop mangé"
    case ballonneInconfortable = "Inconfortable / ballonné"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .encoreFaim: return "arrow.down.circle.fill"
        case .rassasie80: return "checkmark.circle.fill"
        case .rassasiePile: return "equal.circle.fill"
        case .tropMange: return "arrow.up.circle.fill"
        case .ballonneInconfortable: return "exclamationmark.triangle.fill"
        }
    }
}

@Model
final class MealLog {
    var id: UUID
    var dateTime: Date
    var title: String = ""
    var mealDescription: String
    var sensation: MealSensation

    init(dateTime: Date = .now, title: String, mealDescription: String, sensation: MealSensation) {
        self.id = UUID()
        self.dateTime = dateTime
        self.title = title
        self.mealDescription = mealDescription
        self.sensation = sensation
    }
}

