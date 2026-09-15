import Foundation
import SwiftData

enum ProgramStatus: String, Codable, CaseIterable {
    case aVenir = "À venir"
    case enCours = "En cours"
    case termine = "Terminé"
}

/// Conteneur long terme au-dessus des cycles — porte l'objectif global (ex: masse grasse 20%→15%,
/// ou "préparer un marathon") et garde l'historique une fois terminé, avant de passer au suivant.
@Model
final class TrainingProgram {
    var id: UUID
    var title: String
    var programDescription: String?
    var startDate: Date?
    var endDate: Date?
    /// Sert de repli quand les dates ne permettent pas de déduire le statut (pas de date, ou pas
    /// encore commencé/terminé) — sinon `status` prend le dessus automatiquement.
    private var manualStatus: ProgramStatus = ProgramStatus.enCours

    /// Déduit des dates quand elles existent (toujours à jour), sinon retombe sur `manualStatus`.
    var status: ProgramStatus {
        if let endDate, Date.now > endDate { return .termine }
        if let startDate, Date.now < startDate { return .aVenir }
        return manualStatus
    }

    @Relationship(deleteRule: .cascade, inverse: \Cycle.program)
    var cycles: [Cycle] = []

    @Relationship(deleteRule: .cascade, inverse: \ProgramObjective.program)
    var objectives: [ProgramObjective] = []

    var principalObjectives: [ProgramObjective] {
        objectives.filter { $0.category == .principal }.sorted { $0.order < $1.order }
    }

    var secondaryObjectives: [ProgramObjective] {
        objectives.filter { $0.category == .indicateur }.sorted { $0.order < $1.order }
    }

    init(
        title: String,
        programDescription: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        status: ProgramStatus = .enCours
    ) {
        self.id = UUID()
        self.title = title
        self.programDescription = programDescription
        self.startDate = startDate
        self.endDate = endDate
        self.manualStatus = status
    }
}
