import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var completions: [SessionCompletion]
    @Query private var setEntries: [PlannedSetEntry]

    private var calendar: Calendar { Calendar.current }

    private func weekKey(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    kpiSection("Séances par semaine", sessionsPerWeek.map { KPIRowData(label: $0.week.formatted(date: .abbreviated, time: .omitted), value: "\($0.count)") })
                    kpiSection("Séries par groupe musculaire / semaine", setsPerMuscleGroup.map { KPIRowData(label: $0.group, value: "\($0.count)") })
                    kpiSection("Tonnage par groupe musculaire / semaine", tonnagePerMuscleGroup.map { KPIRowData(label: $0.group, value: "\(Int($0.tonnage))kg") })
                    kpiSection("Séries par exercice / semaine", setsPerExercise.map { KPIRowData(label: $0.exercise, value: "\($0.count)") })
                    kpiSection("Charge moyenne par exercice / semaine", averageWeightPerExercise.map { KPIRowData(label: $0.exercise, value: String(format: "%.1fkg", $0.averageWeight)) })
                    kpiSection("PR tracking (Epley)", bestEstimated1RM.map { KPIRowData(label: $0.exercise, value: String(format: "%.1fkg", $0.value)) })
                    kpiSection("Tendance des sensations / semaine", averageSensationPerWeek.map { KPIRowData(label: $0.week.formatted(date: .abbreviated, time: .omitted), value: String(format: "%.1f", $0.average)) })
                    kpiSection("% de difficulté par exercice", hardRatioPerExercise.map { KPIRowData(label: $0.exercise, value: "\(Int($0.ratio * 100))%") })
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Tableau de bord")
        }
    }

    private struct KPIRowData: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    private func kpiSection(_ title: String, _ rows: [KPIRowData]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            AppCard {
                if rows.isEmpty {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 { Divider().overlay(AppTheme.border) }
                            HStack {
                                Text(row.label).foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Text(row.value).foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }

    private var sessionsPerWeek: [(week: Date, count: Int)] {
        let finished = completions.compactMap(\.endTime)
        return Dictionary(grouping: finished, by: { weekKey($0) })
            .map { (week: $0.key, count: $0.value.count) }
            .sorted { $0.week < $1.week }
    }

    private var setsPerMuscleGroup: [(group: String, count: Int)] {
        Dictionary(grouping: setEntries, by: { $0.muscleGroup })
            .map { (group: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var tonnagePerMuscleGroup: [(group: String, tonnage: Double)] {
        Dictionary(grouping: setEntries, by: { $0.muscleGroup })
            .map { (group: $0.key, tonnage: $0.value.reduce(0) { $0 + ($1.tonnage ?? 0) }) }
            .sorted { $0.tonnage > $1.tonnage }
    }

    private var setsPerExercise: [(exercise: String, count: Int)] {
        Dictionary(grouping: setEntries, by: { $0.exerciseName })
            .map { (exercise: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var averageWeightPerExercise: [(exercise: String, averageWeight: Double)] {
        let weightedSets = setEntries.filter { $0.weight != nil }
        let grouped: [String: [PlannedSetEntry]] = Dictionary(grouping: weightedSets, by: { $0.exerciseName })
        var result: [(exercise: String, averageWeight: Double)] = []
        for (exercise, sets) in grouped {
            let weights: [Double] = sets.compactMap { $0.weight }
            let total: Double = weights.reduce(0, +)
            let average: Double = total / Double(weights.count)
            result.append((exercise: exercise, averageWeight: average))
        }
        return result.sorted { $0.averageWeight > $1.averageWeight }
    }

    private var bestEstimated1RM: [(exercise: String, value: Double)] {
        var byExercise: [String: Double] = [:]
        for entry in setEntries {
            guard let rm = entry.estimated1RM else { continue }
            let current = byExercise[entry.exerciseName] ?? 0
            byExercise[entry.exerciseName] = max(current, rm)
        }
        return byExercise
            .map { (exercise: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
    }

    private var averageSensationPerWeek: [(week: Date, average: Double)] {
        Dictionary(grouping: setEntries, by: { weekKey($0.date) })
            .map { (week: $0.key, average: Double($0.value.map { $0.sensation.rawValue }.reduce(0, +)) / Double($0.value.count)) }
            .sorted { $0.week < $1.week }
    }

    private var hardRatioPerExercise: [(exercise: String, ratio: Double)] {
        Dictionary(grouping: setEntries, by: { $0.exerciseName })
            .map { (exercise: $0.key, ratio: Double($0.value.filter { $0.sensation.isHard }.count) / Double($0.value.count)) }
            .sorted { $0.ratio > $1.ratio }
    }
}
