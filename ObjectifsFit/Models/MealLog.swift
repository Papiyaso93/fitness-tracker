import Foundation
import SwiftData

enum MealSensation: String, Codable, CaseIterable {
    case encoreFaim = "Encore faim"
    case rassasie80 = "~80% rassasié"
    case rassasiePile = "Rassasié pile"
    case tropMange = "Trop mangé"
    case ballonneInconfortable = "Inconfortable / ballonné"

    /// Cible : atteindre ce niveau dans 90% des repas de la semaine.
    var isTarget: Bool { self == .rassasie80 }
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

