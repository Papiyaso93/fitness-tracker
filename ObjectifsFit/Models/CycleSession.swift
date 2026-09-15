import Foundation
import SwiftData

enum SessionKind: String, Codable, CaseIterable, Identifiable {
    case musculation = "Musculation"
    case autre = "Autre"

    var id: String { rawValue }
}

/// Une séance planifiée dans un cycle — rattachée à un jour de semaine précis (semaine + jour),
/// pas à un "Jour" séparé : un jour vide n'a simplement aucune séance (repos implicite), et un
/// jour peut en avoir plusieurs (ex: plyo le matin + jambes l'après-midi).
@Model
final class CycleSession {
    var id: UUID
    var weekNumber: Int
    /// 1 = dimanche ... 7 = samedi (convention Calendar), comme WeeklySchedule.
    var weekday: Int
    var title: String
    var kind: SessionKind
    private var objectiveRaw: String
    /// Description libre du contenu — utilisée seulement pour les séances "Autre".
    var sessionDescription: String?
    var order: Int
    /// Séance créée à la volée depuis l'Accueil (pas via le constructeur de programme) — pas de
    /// plan d'exercices associé, et supprimable directement depuis l'écran de saisie.
    var isAdHoc: Bool = false

    var cycle: Cycle?

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.session)
    var exercises: [PlannedExercise] = []

    @Relationship(deleteRule: .cascade, inverse: \SessionCompletion.cycleSession)
    var completion: SessionCompletion?

    var sortedExercises: [PlannedExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    /// Date calendaire réelle de cette occurrence, déduite du cycle parent — une CycleSession
    /// correspond à une seule occurrence (pas de répétition hebdomadaire comme l'ancien système).
    var scheduledDate: Date? {
        cycle?.date(forWeek: weekNumber, weekday: weekday)
    }

    var objective: PhysicalQuality? {
        get { PhysicalQuality(rawValue: objectiveRaw) }
        set { objectiveRaw = newValue?.rawValue ?? "" }
    }

    init(
        weekNumber: Int,
        weekday: Int,
        title: String,
        kind: SessionKind,
        objective: PhysicalQuality?,
        sessionDescription: String? = nil,
        order: Int = 0,
        isAdHoc: Bool = false
    ) {
        self.id = UUID()
        self.weekNumber = weekNumber
        self.weekday = weekday
        self.title = title
        self.kind = kind
        self.objectiveRaw = objective?.rawValue ?? ""
        self.sessionDescription = sessionDescription
        self.order = order
        self.isAdHoc = isAdHoc
    }
}
