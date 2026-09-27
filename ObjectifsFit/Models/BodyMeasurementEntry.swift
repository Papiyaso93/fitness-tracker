import Foundation
import SwiftData

/// Mesure ponctuelle (poids, tour de taille, VO2max, mensurations...) — réutilise le vocabulaire
/// `ObjectiveMetricType` déjà utilisé par les objectifs de programme/cycle, pour qu'un objectif
/// chiffré (ex: "Tour de taille : 83,5→77,5cm") se relie directement à l'historique réel de cette
/// mesure plutôt que d'être une donnée séparée.
@Model
final class BodyMeasurementEntry {
    var id: UUID
    var type: ObjectiveMetricType
    var value: Double
    var date: Date

    init(type: ObjectiveMetricType, value: Double, date: Date = .now) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.date = date
    }
}
