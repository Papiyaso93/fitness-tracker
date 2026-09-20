import Foundation

/// Fenêtre d'agrégation pour le classement des exercices — contrôle la taille de la fenêtre, pas
/// sa position dans le temps (contrairement aux graphes hebdomadaires qui naviguent semaine par
/// semaine) : ce classement est une photo de fréquence, pas une tendance.
enum ExercisePeriod: String, CaseIterable {
    case fourWeeks = "4 dernières semaines"
    case twelveWeeks = "12 dernières semaines"
    case allTime = "Tout l'historique"

    var weeks: Int? {
        switch self {
        case .fourWeeks: return 4
        case .twelveWeeks: return 12
        case .allTime: return nil
        }
    }
}

struct ExerciseRankingRow: Identifiable {
    let exerciseName: String
    let muscleGroup: String
    let count: Int
    var id: String { exerciseName }
}

enum ExerciseRanking {
    /// Classement par fréquence plutôt qu'une tendance semaine par semaine — avec 30+ exercices,
    /// un graphe temporel serait illisible (trop de séries/filtres), alors que la question posée
    /// ("quels exercices je fais souvent vs jamais") est justement une question de fréquence, pas
    /// de tendance. Part de la bibliothèque complète (pas juste des séries loguées) pour que les
    /// exercices jamais faits sur la période apparaissent aussi, à 0, plutôt que d'être absents.
    static func build(setEntries: [PlannedSetEntry], exerciseLibrary: [ExerciseDefinition], period: ExercisePeriod, calendar: Calendar = .current) -> [ExerciseRankingRow] {
        let filteredEntries: [PlannedSetEntry]
        if let weeks = period.weeks {
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            guard let cutoff = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeek) else { return [] }
            filteredEntries = setEntries.filter { $0.date >= cutoff }
        } else {
            filteredEntries = setEntries
        }

        let countsByName = Dictionary(grouping: filteredEntries, by: { $0.exerciseName }).mapValues(\.count)
        return exerciseLibrary
            .map { definition in
                ExerciseRankingRow(exerciseName: definition.name, muscleGroup: definition.muscleGroup, count: countsByName[definition.name] ?? 0)
            }
            .sorted { $0.count > $1.count }
    }
}
