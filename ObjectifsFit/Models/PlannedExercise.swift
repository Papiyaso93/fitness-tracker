import Foundation
import SwiftData

/// Un exercice planifié dans une séance de musculation du nouveau constructeur — distinct
/// d'`ExercisePlan` (lié au Cycle 1 existant), pour ne pas recoupler les deux systèmes.
@Model
final class PlannedExercise {
    var id: UUID
    var muscleGroup: String
    var exerciseName: String
    var technique: SetTechnique
    var resistanceMode: ResistanceMode
    var targetSets: Int
    var targetWeight: Double?
    var isRepsRange: Bool
    var targetRepsMin: Int
    var targetRepsMax: Int
    var order: Int

    var session: CycleSession?

    init(
        muscleGroup: String,
        exerciseName: String,
        technique: SetTechnique = .normal,
        resistanceMode: ResistanceMode,
        targetSets: Int,
        targetWeight: Double? = nil,
        isRepsRange: Bool,
        targetRepsMin: Int,
        targetRepsMax: Int,
        order: Int = 0
    ) {
        self.id = UUID()
        self.muscleGroup = muscleGroup
        self.exerciseName = exerciseName
        self.technique = technique
        self.resistanceMode = resistanceMode
        self.targetSets = targetSets
        self.targetWeight = targetWeight
        self.isRepsRange = isRepsRange
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.order = order
    }

    var repsLabel: String {
        isRepsRange ? "\(targetRepsMin)-\(targetRepsMax)" : "\(targetRepsMin)"
    }

    /// "Machine · 2 séries · 110kg · 8-10 reps" — même format que SessionDetailView.
    var summary: String {
        var parts = [resistanceMode.rawValue, "\(targetSets) séries"]
        if let targetWeight {
            parts.append("\(Int(targetWeight))kg")
        }
        parts.append("\(repsLabel) reps")
        return parts.joined(separator: " · ")
    }
}
