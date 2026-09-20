import Foundation

/// Un record battu — seulement les séries qui ont dépassé le meilleur poids connu jusque-là pour
/// cet exercice, pas toutes les séries loguées.
struct PRHistoryEntry: Identifiable {
    let date: Date
    let weight: Double
    let reps: Int
    let previousWeight: Double?
    var id: Date { date }
    var delta: Double? { previousWeight.map { weight - $0 } }
}

enum PRHistoryBuilder {
    /// Le poids seul détermine le record (les reps ne sont que du contexte, pas une deuxième
    /// dimension), et l'élastique est exclu comme pour le tonnage : pas d'équivalent kg fiable
    /// (`comparableToKilograms`).
    static func build(setEntries: [PlannedSetEntry], exerciseName: String) -> [PRHistoryEntry] {
        let weighted = setEntries
            .filter { $0.exerciseName == exerciseName && $0.weight != nil && $0.resistanceMode.comparableToKilograms }
            .sorted { $0.date < $1.date }

        var records: [PRHistoryEntry] = []
        var currentBest = -Double.infinity
        for entry in weighted {
            guard let weight = entry.weight, weight > currentBest else { continue }
            records.append(PRHistoryEntry(date: entry.date, weight: weight, reps: entry.reps, previousWeight: records.last?.weight))
            currentBest = weight
        }
        return records.reversed()
    }
}

enum WeightFormat {
    static func string(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
