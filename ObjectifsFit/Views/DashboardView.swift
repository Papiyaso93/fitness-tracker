import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var completions: [SessionCompletion]
    @Query private var setEntries: [PlannedSetEntry]

    @State private var showMusculation = true
    @State private var showAutre = true

    private var calendar: Calendar { Calendar.current }

    private func weekKey(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BilanCoachCardView()
                    sessionsChart
                    muscleGroupChart
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

    private struct WeeklySessionEntry: Identifiable {
        let week: Date
        let kind: String
        let count: Int
        var id: String { "\(week)-\(kind)" }
        var weekLabel: String { AppDateFormat.dayMonth.string(from: week) }
    }

    /// Type effectif d'une séance réalisée — reprend l'adaptation ("Autre séance réalisée ?") si
    /// elle existe, sinon le type planifié.
    private func effectiveKind(_ completion: SessionCompletion) -> SessionKind {
        if completion.isAdapted {
            return completion.adaptedKind ?? .autre
        }
        return completion.cycleSession?.kind ?? .autre
    }

    /// Les 4 dernières semaines (la plus récente en dernier), calées sur le lundi comme le reste
    /// de l'app — sert de fenêtre fixe pour les aperçus compacts du Tableau de bord.
    private func lastNWeeks(_ count: Int) -> [Date] {
        let currentWeek = weekKey(.now)
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeek)
        }.sorted()
    }

    /// Comblé à 0 sur les 4 dernières semaines — un axe continu et une fenêtre fixe plutôt qu'un
    /// graphe qui s'étale sur tout l'historique et devient illisible une fois les données denses.
    private var weeklySessionEntries: [WeeklySessionEntry] {
        let finished = completions.filter { $0.endTime != nil }
        guard !finished.isEmpty else { return [] }
        let grouped = Dictionary(grouping: finished) { weekKey($0.endTime!) }

        var entries: [WeeklySessionEntry] = []
        for week in lastNWeeks(4) {
            let weekCompletions = grouped[week] ?? []
            let musculationCount = weekCompletions.filter { effectiveKind($0) == .musculation }.count
            let autreCount = weekCompletions.count - musculationCount
            entries.append(WeeklySessionEntry(week: week, kind: "Musculation", count: musculationCount))
            entries.append(WeeklySessionEntry(week: week, kind: "Autre", count: autreCount))
        }
        return entries
    }

    private var filteredSessionEntries: [WeeklySessionEntry] {
        weeklySessionEntries.filter { entry in
            (entry.kind == "Musculation" && showMusculation) || (entry.kind == "Autre" && showAutre)
        }
    }

    private var sessionsChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Séances par semaine")
            AppCard {
                if weeklySessionEntries.isEmpty {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else {
                    HStack {
                        Spacer(minLength: 0)
                        HStack(spacing: 10) {
                            legendDot(color: AppTheme.accent, label: "Musculation", isActive: showMusculation) {
                                showMusculation.toggle()
                            }
                            legendDot(color: AppTheme.secondary, label: "Autre", isActive: showAutre) {
                                showAutre.toggle()
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 10)

                    if !showMusculation && !showAutre {
                        Text("Aucun type sélectionné")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                    } else {
                    Chart(filteredSessionEntries) { entry in
                        BarMark(
                            x: .value("Semaine", entry.weekLabel),
                            y: .value("Séances", entry.count),
                            width: .fixed(22)
                        )
                        .foregroundStyle(by: .value("Type", entry.kind))
                        .cornerRadius(3)
                    }
                    .chartForegroundStyleScale([
                        "Musculation": AppTheme.accent,
                        "Autre": AppTheme.secondary
                    ])
                    .chartLegend(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                                .font(.system(size: 9))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            if let label = value.as(String.self) {
                                AxisValueLabel(label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    .frame(height: 170)
                    }
                }
            }
        }
    }

    private func legendDot(color: Color, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? color : AppTheme.textSecondary.opacity(0.5))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isActive ? color.opacity(0.12) : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private struct WeeklyMuscleEntry: Identifiable {
        let week: Date
        let group: String
        let count: Int
        var id: String { "\(week)-\(group)" }
        var weekLabel: String { AppDateFormat.dayMonth.string(from: week) }
    }

    /// Même fenêtre fixe de 4 semaines que `weeklySessionEntries`, empilée par groupe musculaire
    /// avec les couleurs déjà utilisées ailleurs dans l'app (`MuscleGroupStyle`) pour rester
    /// cohérent avec les tags d'exercices.
    private var weeklyMuscleGroupEntries: [WeeklyMuscleEntry] {
        guard !setEntries.isEmpty else { return [] }
        let grouped = Dictionary(grouping: setEntries) { weekKey($0.date) }

        var entries: [WeeklyMuscleEntry] = []
        for week in lastNWeeks(4) {
            let weekEntries = grouped[week] ?? []
            let countsByGroup = Dictionary(grouping: weekEntries, by: { $0.muscleGroup }).mapValues(\.count)
            for group in MuscleGroupStyle.order {
                entries.append(WeeklyMuscleEntry(week: week, group: group, count: countsByGroup[group] ?? 0))
            }
        }
        return entries
    }

    private var muscleGroupChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Séries par groupe musculaire / semaine")
            AppCard {
                if weeklyMuscleGroupEntries.isEmpty {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else {
                    Chart(weeklyMuscleGroupEntries) { entry in
                        BarMark(
                            x: .value("Semaine", entry.weekLabel),
                            y: .value("Séries", entry.count),
                            width: .fixed(22)
                        )
                        .foregroundStyle(by: .value("Groupe", entry.group))
                        .cornerRadius(3)
                    }
                    .chartForegroundStyleScale(
                        domain: MuscleGroupStyle.order,
                        range: MuscleGroupStyle.order.map(MuscleGroupStyle.color(for:))
                    )
                    .chartLegend(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                                .font(.system(size: 9))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            if let label = value.as(String.self) {
                                AxisValueLabel(label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    .frame(height: 170)
                }
            }
        }
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
