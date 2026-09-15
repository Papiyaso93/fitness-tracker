import Foundation
import SwiftData

/// Bibliothèque personnelle d'exercices, qui s'enrichit au fil du temps (création libre depuis
/// le log d'une série) — sert à alimenter le picker d'exercices par groupe musculaire.
@Model
final class ExerciseDefinition {
    var id: UUID
    var name: String
    var muscleGroup: String

    init(name: String, muscleGroup: String) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
    }
}
