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
    /// Fraction du poids de corps réellement soulevée (mode Poids du corps/Lesté), éditable — pré-
    /// rempli à la création par une estimation (`BodyweightCoefficients`), corrigeable ensuite.
    var tonnageCoefficient: Double = 1.0

    init(name: String, muscleGroup: String, primaryMuscles: [String] = [], secondaryMuscles: [String] = [], tonnageCoefficient: Double? = nil) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.tonnageCoefficient = tonnageCoefficient ?? BodyweightCoefficients.defaultCoefficient(forExerciseNamed: name)
    }
}
