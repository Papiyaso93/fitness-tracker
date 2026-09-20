import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var completions: [SessionCompletion]
    @Query private var setEntries: [PlannedSetEntry]
    @Query(sort: \ExerciseDefinition.name) private var exerciseLibrary: [ExerciseDefinition]

    @State private var showMusculation = true
    @State private var showAutre = true
    @State private var sessionsWindowOffset = 0
    @State private var visibleMuscleGroups: Set<String> = Set(MuscleGroupStyle.order)
    @State private var muscleGroupWindowOffset = 0
    @State private var visibleTonnageMuscleGroups: Set<String> = Set(MuscleGroupStyle.order)
    @State private var muscleGroupTonnageWindowOffset = 0
    @State private var exercisePeriod: ExercisePeriod = .fourWeeks
    @State private var visibleExerciseGroups: Set<String> = Set(MuscleGroupStyle.order)

    private var calendar: Calendar { Calendar.current }

    private func weekKey(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    /// Fenêtre de 4 semaines, décalée en arrière de `offsetWindows` blocs de 4 semaines —
    /// `offsetWindows == 0` correspond aux 4 dernières semaines (fenêtre la plus récente).
    private func weeksWindow(offsetWindows: Int) -> [Date] {
        let currentWeek = weekKey(.now)
        let endWeek = calendar.date(byAdding: .weekOfYear, value: -offsetWindows * 4, to: currentWeek) ?? currentWeek
        return (0..<4).compactMap { i in
            calendar.date(byAdding: .weekOfYear, value: -i, to: endWeek)
        }.sorted()
    }

    private func windowRangeLabel(_ weeks: [Date]) -> String {
        guard let start = weeks.first, let end = weeks.last else { return "" }
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: end) ?? end
        return "\(AppDateFormat.dayMonth.string(from: start)) — \(AppDateFormat.dayMonthYear.string(from: endOfWeek))"
    }

    private func windowNavigator(weeks: [Date], offset: Binding<Int>) -> some View {
        HStack {
            Button {
                offset.wrappedValue += 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
            Text(windowRangeLabel(weeks))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: 0)
            Button {
                if offset.wrappedValue > 0 { offset.wrappedValue -= 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(offset.wrappedValue > 0 ? AppTheme.textSecondary : AppTheme.textSecondary.opacity(0.3))
            }
            .disabled(offset.wrappedValue == 0)
        }
        .buttonStyle(.plain)
    }

    private func periodMenu(selection: Binding<ExercisePeriod>) -> some View {
        Menu {
            ForEach(ExercisePeriod.allCases, id: \.self) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    if selection.wrappedValue == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue.rawValue)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.accent)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BilanCoachCardView()
                    sessionsChart
                    muscleGroupChart
                    muscleGroupTonnageChart
                    exerciseRankingChart
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

    /// Comblé à 0 sur les 4 dernières semaines — un axe continu et une fenêtre fixe plutôt qu'un
    /// graphe qui s'étale sur tout l'historique et devient illisible une fois les données denses.
    private var weeklySessionEntries: [WeeklySessionEntry] {
        let finished = completions.filter { $0.endTime != nil }
        guard !finished.isEmpty else { return [] }
        let grouped = Dictionary(grouping: finished) { weekKey($0.endTime!) }

        var entries: [WeeklySessionEntry] = []
        for week in weeksWindow(offsetWindows: sessionsWindowOffset) {
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
                    windowNavigator(weeks: weeksWindow(offsetWindows: sessionsWindowOffset), offset: $sessionsWindowOffset)
                        .padding(.bottom, 10)

                    HStack {
                        Spacer(minLength: 0)
                        HStack(spacing: 10) {
                            legendToggleChip(color: AppTheme.accent, label: "Musculation", isActive: showMusculation) {
                                showMusculation.toggle()
                            }
                            legendToggleChip(color: AppTheme.secondary, label: "Autre", isActive: showAutre) {
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
        for week in weeksWindow(offsetWindows: muscleGroupWindowOffset) {
            let weekEntries = grouped[week] ?? []
            let countsByGroup = Dictionary(grouping: weekEntries, by: { $0.muscleGroup }).mapValues(\.count)
            for group in MuscleGroupStyle.order {
                entries.append(WeeklyMuscleEntry(week: week, group: group, count: countsByGroup[group] ?? 0))
            }
        }
        return entries
    }

    private var filteredMuscleGroupEntries: [WeeklyMuscleEntry] {
        weeklyMuscleGroupEntries.filter { visibleMuscleGroups.contains($0.group) }
    }

    private var muscleGroupChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Séries par groupe musculaire / semaine")
            AppCard {
                if weeklyMuscleGroupEntries.isEmpty {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else {
                    windowNavigator(weeks: weeksWindow(offsetWindows: muscleGroupWindowOffset), offset: $muscleGroupWindowOffset)
                        .padding(.bottom, 10)

                    FlowLayout(spacing: 6) {
                        ForEach(MuscleGroupStyle.order, id: \.self) { group in
                            legendToggleChip(color: MuscleGroupStyle.color(for: group), label: group, isActive: visibleMuscleGroups.contains(group)) {
                                if visibleMuscleGroups.contains(group) {
                                    visibleMuscleGroups.remove(group)
                                } else {
                                    visibleMuscleGroups.insert(group)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 10)

                    if visibleMuscleGroups.isEmpty {
                        Text("Aucun groupe sélectionné")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                    } else {
                    Chart(filteredMuscleGroupEntries) { entry in
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
    }

    private struct WeeklyMuscleTonnageEntry: Identifiable {
        let week: Date
        let group: String
        let tonnage: Double
        var id: String { "\(week)-\(group)" }
        var weekLabel: String { AppDateFormat.dayMonth.string(from: week) }
    }

    private var weeklyMuscleTonnageEntries: [WeeklyMuscleTonnageEntry] {
        guard !setEntries.isEmpty else { return [] }
        let grouped = Dictionary(grouping: setEntries) { weekKey($0.date) }

        var entries: [WeeklyMuscleTonnageEntry] = []
        for week in weeksWindow(offsetWindows: muscleGroupTonnageWindowOffset) {
            let weekEntries = grouped[week] ?? []
            let tonnageByGroup = Dictionary(grouping: weekEntries, by: { $0.muscleGroup })
                .mapValues { $0.reduce(0) { $0 + ($1.tonnage ?? 0) } }
            for group in MuscleGroupStyle.order {
                entries.append(WeeklyMuscleTonnageEntry(week: week, group: group, tonnage: tonnageByGroup[group] ?? 0))
            }
        }
        return entries
    }

    private var filteredMuscleTonnageEntries: [WeeklyMuscleTonnageEntry] {
        weeklyMuscleTonnageEntries.filter { visibleTonnageMuscleGroups.contains($0.group) }
    }

    private var muscleGroupTonnageChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Tonnage par groupe musculaire / semaine")
            AppCard {
                if weeklyMuscleTonnageEntries.isEmpty {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else {
                    windowNavigator(weeks: weeksWindow(offsetWindows: muscleGroupTonnageWindowOffset), offset: $muscleGroupTonnageWindowOffset)
                        .padding(.bottom, 10)

                    FlowLayout(spacing: 6) {
                        ForEach(MuscleGroupStyle.order, id: \.self) { group in
                            legendToggleChip(color: MuscleGroupStyle.color(for: group), label: group, isActive: visibleTonnageMuscleGroups.contains(group)) {
                                if visibleTonnageMuscleGroups.contains(group) {
                                    visibleTonnageMuscleGroups.remove(group)
                                } else {
                                    visibleTonnageMuscleGroups.insert(group)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 10)

                    if visibleTonnageMuscleGroups.isEmpty {
                        Text("Aucun groupe sélectionné")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                    } else {
                    Chart(filteredMuscleTonnageEntries) { entry in
                        BarMark(
                            x: .value("Semaine", entry.weekLabel),
                            y: .value("Tonnage", entry.tonnage),
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
    }

    private let collapsedExerciseCount = 6

    private var exerciseRanking: [ExerciseRankingRow] {
        ExerciseRanking.build(setEntries: setEntries, exerciseLibrary: exerciseLibrary, period: exercisePeriod, calendar: calendar)
            .filter { visibleExerciseGroups.contains($0.muscleGroup) }
    }

    private var visibleExerciseRanking: [ExerciseRankingRow] {
        Array(exerciseRanking.prefix(collapsedExerciseCount))
    }

    private var exerciseRankingChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Séries par exercice")
            AppCard {
                HStack {
                    Spacer(minLength: 0)
                    periodMenu(selection: $exercisePeriod)
                }
                .padding(.bottom, 10)

                FlowLayout(spacing: 6) {
                    ForEach(MuscleGroupStyle.order, id: \.self) { group in
                        legendToggleChip(color: MuscleGroupStyle.color(for: group), label: group, isActive: visibleExerciseGroups.contains(group)) {
                            if visibleExerciseGroups.contains(group) {
                                visibleExerciseGroups.remove(group)
                            } else {
                                visibleExerciseGroups.insert(group)
                            }
                        }
                    }
                }
                .padding(.bottom, 12)

                if visibleExerciseGroups.isEmpty {
                    Text("Aucun groupe sélectionné").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else if exerciseRanking.isEmpty {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else {
                    let maxCount = max(exerciseRanking.first?.count ?? 1, 1)
                    VStack(spacing: 12) {
                        ForEach(visibleExerciseRanking) { row in
                            ExerciseRankingRowView(row: row, maxCount: maxCount)
                        }
                    }

                    if exerciseRanking.count > collapsedExerciseCount {
                        NavigationLink {
                            ExerciseFrequencyView(initialPeriod: exercisePeriod, initialVisibleGroups: visibleExerciseGroups)
                        } label: {
                            Text("Voir tout")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
