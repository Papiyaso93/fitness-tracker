import Foundation

struct IntensityRankingRow: Identifiable {
    let exerciseName: String
    let muscleGroup: String
    let nearFailureCount: Int
    let totalCount: Int
    var id: String { exerciseName }
    var percentage: Double { totalCount == 0 ? 0 : Double(nearFailureCount) / Double(totalCount) * 100 }
}

enum IntensityRanking {
    /// "Proche de l'échec" = Très difficile ou Échec (2 reps en réserve ou moins) — pas Difficile,
    /// qui reste une série de travail normale. Seuls les exercices avec au moins une série sur la
    /// période apparaissent (un ratio 0/0 n'a pas de sens).
    static func build(setEntries: [PlannedSetEntry], period: ExercisePeriod, calendar: Calendar = .current) -> [IntensityRankingRow] {
        let filteredEntries: [PlannedSetEntry]
        if let weeks = period.weeks {
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            guard let cutoff = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeek) else { return [] }
            filteredEntries = setEntries.filter { $0.date >= cutoff }
        } else {
            filteredEntries = setEntries
        }

        let grouped = Dictionary(grouping: filteredEntries, by: { $0.exerciseName })
        return grouped.map { name, entries in
            let nearFailure = entries.filter { $0.sensation == .tresDifficile || $0.sensation == .echec }.count
            return IntensityRankingRow(exerciseName: name, muscleGroup: entries.first?.muscleGroup ?? "", nearFailureCount: nearFailure, totalCount: entries.count)
        }
        // Départage explicite par nom sur les égalités de pourcentage — sans ça, l'ordre dépend de
        // l'itération du Dictionary construit à partir de `setEntries` (non trié), qui peut varier
        // d'un recalcul à l'autre et donnait l'impression que la liste se mélangeait toute seule.
        .sorted { $0.percentage == $1.percentage ? $0.exerciseName < $1.exerciseName : $0.percentage > $1.percentage }
    }
}
