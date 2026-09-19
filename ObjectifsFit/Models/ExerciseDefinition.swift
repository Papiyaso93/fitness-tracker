import Foundation
import SwiftData

/// Bibliothèque personnelle d'exercices, qui s'enrichit au fil du temps (création libre depuis
/// le log d'une série) — sert à alimenter le picker d'exercices par groupe musculaire.
@Model
final class ExerciseDefinition {
    var id: UUID
    var name: String
    var muscleGroup: String
    /// Muscles réellement ciblés par l'exercice (niveau plus fin que `muscleGroup`), pour affiner
    /// le suivi de volume — ex: "Dos" reste le groupe large, mais "Grand dorsal" et "Trapèzes" sont
    /// les muscles précis. Basé sur des sources anatomiques (ExRx.net et équivalents), pas deviné.
    var primaryMuscles: [String] = []
    var secondaryMuscles: [String] = []

    init(name: String, muscleGroup: String, primaryMuscles: [String] = [], secondaryMuscles: [String] = []) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
    }
}
