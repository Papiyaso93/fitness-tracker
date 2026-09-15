import Foundation
import SwiftData

enum CycleType: String, Codable, CaseIterable {
    case eventPrep = "Préparation événement"
    case transition = "Transition"
    case offCycle = "Hors cycle"
    case standard = "Standard"
}

@Model
final class Cycle {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var type: CycleType
    var isActive: Bool
    var notes: String?
    var program: TrainingProgram?
    private var objectifsPrincipauxRaw: [String] = []
    private var objectifsSecondairesRaw: [String] = []

    var objectifsPrincipaux: [PhysicalQuality] {
        get { objectifsPrincipauxRaw.compactMap(PhysicalQuality.init(rawValue:)) }
        set { objectifsPrincipauxRaw = newValue.map(\.rawValue) }
    }

    var objectifsSecondaires: [PhysicalQuality] {
        get { objectifsSecondairesRaw.compactMap(PhysicalQuality.init(rawValue:)) }
        set { objectifsSecondairesRaw = newValue.map(\.rawValue) }
    }

    @Relationship(deleteRule: .cascade, inverse: \ProgramObjective.cycle)
    var objectives: [ProgramObjective] = []

    @Relationship(deleteRule: .cascade, inverse: \CycleSession.cycle)
    var trainingSessions: [CycleSession] = []

    var sortedObjectives: [ProgramObjective] {
        objectives.sorted { $0.order < $1.order }
    }

    init(
        name: String,
        startDate: Date,
        endDate: Date,
        type: CycleType,
        isActive: Bool = true,
        notes: String? = nil,
        program: TrainingProgram? = nil,
        objectifsPrincipaux: [PhysicalQuality] = [],
        objectifsSecondaires: [PhysicalQuality] = []
    ) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.type = type
        self.isActive = isActive
        self.notes = notes
        self.program = program
        self.objectifsPrincipauxRaw = objectifsPrincipaux.map(\.rawValue)
        self.objectifsSecondairesRaw = objectifsSecondaires.map(\.rawValue)
    }

    /// Lundi de la semaine 1 — les semaines du cycle sont toujours calées sur le lundi, même si
    /// `startDate` tombe un autre jour, pour que "semaine N" corresponde à un vrai lundi-dimanche
    /// partout dans l'app (planning, sélection du jour, etc.).
    private var weekOneMonday: Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: startDate) // 1=dimanche ... 7=samedi
        let daysSinceMonday = (weekday + 5) % 7 // lundi=0 ... dimanche=6
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: startDate)) ?? startDate
    }

    /// Numéro de semaine (1-indexé) dans le cycle pour une date donnée.
    func weekNumber(for date: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: weekOneMonday, to: date).day ?? 0
        return max(1, days / 7 + 1)
    }

    /// Date calendaire réelle d'un jour donné (1=dimanche...7=samedi, convention Calendar) dans une
    /// semaine du cycle (1-indexée) — toujours calée sur le lundi via `weekOneMonday`.
    func date(forWeek weekNumber: Int, weekday: Int) -> Date? {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(byAdding: .day, value: (weekNumber - 1) * 7, to: weekOneMonday) else { return nil }
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            if calendar.component(.weekday, from: day) == weekday { return day }
        }
        return nil
    }

    /// Déduit du statut à partir des dates — toujours à jour, pas besoin de le stocker/màj à la main.
    var status: ProgramStatus {
        let now = Date.now
        if now < startDate { return .aVenir }
        if now > endDate { return .termine }
        return .enCours
    }

    /// Nombre de semaines du cycle, déduit des dates (pas de champ séparé à maintenir).
    var weekCount: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(1, Int((Double(days) / 7).rounded(.up)))
    }
}
