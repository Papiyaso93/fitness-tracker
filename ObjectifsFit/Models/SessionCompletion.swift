import Foundation
import SwiftData

/// Équivalent de `SessionLog` pour le nouveau système (Programme/Cycle/CycleSession) — l'exécution
/// réelle d'une `CycleSession` planifiée. Relation 1:1 car une CycleSession correspond à une seule
/// occurrence calendaire (contrairement à l'ancien SessionType qui se répétait chaque semaine).
@Model
final class SessionCompletion {
    var id: UUID
    var startTime: Date?
    var endTime: Date?
    /// Pour les séances "Autre" : commentaire libre + le plan a-t-il été appliqué tel quel.
    var simpleComment: String?
    var planApplied: Bool?

    /// "Autre séance réalisée ?" — permet de loguer un contenu différent de la séance planifiée
    /// sans modifier le plan lui-même (ex: prévu Musculation, mais en fait fait du cardio ce jour-là).
    var isAdapted: Bool = false
    var adaptedTitle: String?
    private var adaptedKindRaw: String = ""

    var cycleSession: CycleSession?

    @Relationship(deleteRule: .cascade, inverse: \PlannedSetEntry.completion)
    var setEntries: [PlannedSetEntry] = []

    var adaptedKind: SessionKind? {
        get { SessionKind(rawValue: adaptedKindRaw) }
        set { adaptedKindRaw = newValue?.rawValue ?? "" }
    }

    init(
        startTime: Date? = nil,
        endTime: Date? = nil,
        simpleComment: String? = nil,
        planApplied: Bool? = nil,
        isAdapted: Bool = false,
        adaptedTitle: String? = nil,
        adaptedKind: SessionKind? = nil
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.simpleComment = simpleComment
        self.planApplied = planApplied
        self.isAdapted = isAdapted
        self.adaptedTitle = adaptedTitle
        self.adaptedKindRaw = adaptedKind?.rawValue ?? ""
    }

    var durationMinutes: Int? {
        guard let startTime, let endTime else { return nil }
        return Int(endTime.timeIntervalSince(startTime) / 60)
    }
}

/// Équivalent de `SetLog` pour le nouveau système — une série réellement effectuée.
@Model
final class PlannedSetEntry {
    var id: UUID
    var date: Date
    var exerciseName: String
    var muscleGroup: String
    var resistanceMode: ResistanceMode
    var weight: Double?
    var bodyWeight: Double?
    var reps: Int
    var sensation: SensationLevel
    var comment: String?
    var coefficient: Double
    var technique: SetTechnique
    var techniqueOtherLabel: String?
    var groupId: UUID?

    var completion: SessionCompletion?

    init(
        date: Date = .now,
        exerciseName: String,
        muscleGroup: String,
        resistanceMode: ResistanceMode,
        weight: Double? = nil,
        bodyWeight: Double? = nil,
        reps: Int,
        sensation: SensationLevel,
        comment: String? = nil,
        coefficient: Double = 1.0,
        technique: SetTechnique = .normal,
        techniqueOtherLabel: String? = nil,
        groupId: UUID? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.resistanceMode = resistanceMode
        self.weight = weight
        self.bodyWeight = bodyWeight
        self.reps = reps
        self.sensation = sensation
        self.comment = comment
        self.coefficient = coefficient
        self.technique = technique
        self.techniqueOtherLabel = techniqueOtherLabel
        self.groupId = groupId
    }

    var tonnage: Double? {
        guard resistanceMode.comparableToKilograms else { return nil }
        let effectiveWeight = (weight ?? 0) + (bodyWeight ?? 0)
        return effectiveWeight * Double(reps) * coefficient
    }

    /// Force estimée (formule d'Epley) pour le PR tracking : charge × (1 + reps/30).
    var estimated1RM: Double? {
        guard resistanceMode.comparableToKilograms, let weight else { return nil }
        let effectiveWeight = weight + (bodyWeight ?? 0)
        return effectiveWeight * (1 + Double(reps) / 30.0)
    }
}
