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

extension BodyMeasurementEntry {
    /// "-2kg vs il y a 3j" — variation par rapport à la mesure précédente du même type. Partagée
    /// entre la carte du jour (Accueil) et l'historique détaillé plutôt que recalculée deux fois.
    static func progressionLabel(current: BodyMeasurementEntry, previous: BodyMeasurementEntry?) -> String? {
        guard let previous else { return nil }
        let delta = current.value - previous.value
        let sign = delta > 0 ? "+" : ""
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: previous.date),
            to: Calendar.current.startOfDay(for: current.date)
        ).day ?? 0
        let deltaText = "\(sign)\(delta.formatted())\(current.type.unit)"
        return days > 0 ? "\(deltaText) vs il y a \(days)j" : deltaText
    }
}
