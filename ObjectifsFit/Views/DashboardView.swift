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
    @State private var selectedAverageWeightExercise: String?
    @State private var averageWeightWindowOffset = 0
    @State private var selectedPRExercise: String?
    @State private var visibleSensations: Set<SensationLevel> = Set(SensationLevel.allCases)
    @State private var sensationWindowOffset = 0
    @State private var intensityPeriod: ExercisePeriod = .fourWeeks
    @State private var visibleIntensityGroups: Set<String> = Set(MuscleGroupStyle.order)

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
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(windowRangeLabel(weeks))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
            }
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

                    dashboardSectionHeader("Volume", systemImage: "dumbbell.fill")
                    sessionsChart
                    muscleGroupChart
                    muscleGroupTonnageChart
                    exerciseRankingChart

                    dashboardSectionHeader("Effort", systemImage: "flame.fill")
                    sensationChart
                    intensityRankingChart

                    dashboardSectionHeader("Performance", systemImage: "chart.line.uptrend.xyaxis")
                    averageWeightChart
                    prTrackingChart
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Tableau de bord")
        }
    }

    /// Titre de section (Volume/Effort/Performance) — pastille d'icône pleine + texte, plus gros
    /// et gras que `SectionLabel` (titre de carte), pour marquer clairement les 3 blocs du
    /// Tableau de bord.
    private func dashboardSectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9)
                .fill(AppTheme.accent)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 4)
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
            SectionLabel(text: "Séries par groupe musculaire")
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
            SectionLabel(text: "Tonnage par groupe musculaire")
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

    private let collapsedExerciseCount = 5

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

    private struct AverageWeightPoint: Identifiable {
        let week: Date
        let averageWeight: Double
        var id: Date { week }
        var weekLabel: String { AppDateFormat.dayMonth.string(from: week) }
    }

    /// Exercice le plus pratiqué (avec poids logué) — présélectionné tant que l'utilisateur n'a
    /// pas choisi un exercice précis.
    private var defaultAverageWeightExercise: String? {
        let weighted = setEntries.filter { $0.weight != nil }
        let counts = Dictionary(grouping: weighted, by: { $0.exerciseName }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Progression sur UN exercice à la fois plutôt qu'une comparaison entre exercices — avec
    /// 30+ exercices, superposer toutes leurs courbes serait illisible (cf. Metabase), alors que
    /// la vraie question ("est-ce que je progresse sur cet exercice précis ?") se lit exercice par
    /// exercice. Une semaine sans série est comptée à 0 (creux visible sur la courbe) plutôt que
    /// d'être sautée, pour bien voir les trous d'assiduité sur cet exercice précis.
    private var averageWeightSeries: [AverageWeightPoint] {
        guard let exerciseName = selectedAverageWeightExercise ?? defaultAverageWeightExercise else { return [] }
        let relevant = setEntries.filter { $0.exerciseName == exerciseName && $0.weight != nil }
        let grouped = Dictionary(grouping: relevant) { weekKey($0.date) }
        return weeksWindow(offsetWindows: averageWeightWindowOffset).map { week in
            let weights = (grouped[week] ?? []).compactMap(\.weight)
            let average = weights.isEmpty ? 0 : weights.reduce(0, +) / Double(weights.count)
            return AverageWeightPoint(week: week, averageWeight: average)
        }
    }

    /// Distinct de `averageWeightSeries.isEmpty` (qui ne l'est jamais désormais, vu les 0
    /// explicites) — sert à distinguer "jamais loguée avec un poids" (ex: exercice au poids du
    /// corps) d'une simple semaine creuse.
    private var hasAnyWeightDataForSelectedExercise: Bool {
        guard let exerciseName = selectedAverageWeightExercise else { return false }
        return setEntries.contains { $0.exerciseName == exerciseName && $0.weight != nil }
    }

    private var averageWeightChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Charge moyenne par exercice")
            AppCard {
                if let exerciseName = selectedAverageWeightExercise {
                    Menu {
                        ForEach(exerciseLibrary) { definition in
                            Button(definition.name) {
                                selectedAverageWeightExercise = definition.name
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Spacer(minLength: 0)
                            Text(exerciseName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.bottom, 12)

                    windowNavigator(weeks: weeksWindow(offsetWindows: averageWeightWindowOffset), offset: $averageWeightWindowOffset)
                        .padding(.bottom, 10)

                    if !hasAnyWeightDataForSelectedExercise {
                        Text("Pas de charge enregistrée pour cet exercice")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                    } else {
                        let windowLabels = weeksWindow(offsetWindows: averageWeightWindowOffset).map { AppDateFormat.dayMonth.string(from: $0) }
                        Chart(averageWeightSeries) { point in
                            LineMark(
                                x: .value("Semaine", point.weekLabel),
                                y: .value("Charge moyenne", point.averageWeight)
                            )
                            .foregroundStyle(AppTheme.accent)
                            .interpolationMethod(.monotone)
                            .symbol(Circle())
                        }
                        .chartXScale(domain: windowLabels)
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
                        .frame(height: 150)
                    }
                } else {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .onAppear {
            if selectedAverageWeightExercise == nil {
                selectedAverageWeightExercise = defaultAverageWeightExercise
            }
        }
    }

    private var prHistory: [PRHistoryEntry] {
        guard let exerciseName = selectedPRExercise else { return [] }
        return PRHistoryBuilder.build(setEntries: setEntries, exerciseName: exerciseName)
    }

    private let collapsedPRCount = 5

    private var prTrackingChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Charge max par exercice")
            AppCard {
                if let exerciseName = selectedPRExercise {
                    Menu {
                        ForEach(exerciseLibrary) { definition in
                            Button(definition.name) {
                                selectedPRExercise = definition.name
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Spacer(minLength: 0)
                            Text(exerciseName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.bottom, 12)

                    if let record = prHistory.first {
                        VStack(spacing: 2) {
                            Text("RECORD ACTUEL")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.4)
                                .foregroundStyle(AppTheme.accent)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(WeightFormat.string(record.weight))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("kg")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("× \(record.reps) reps")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(AppDateFormat.dayMonthYear.string(from: record.date))
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 12)

                        Text("HISTORIQUE DES RECORDS")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.bottom, 6)

                        VStack(spacing: 0) {
                            ForEach(Array(prHistory.prefix(collapsedPRCount).enumerated()), id: \.element.id) { index, entry in
                                if index > 0 { Divider().overlay(AppTheme.border) }
                                PRHistoryRowView(entry: entry)
                            }
                        }

                        if prHistory.count > collapsedPRCount {
                            NavigationLink {
                                PRHistoryView(exerciseName: exerciseName)
                            } label: {
                                Text("Voir tout")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("Pas de charge enregistrée pour cet exercice")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                } else {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .onAppear {
            if selectedPRExercise == nil {
                selectedPRExercise = defaultAverageWeightExercise
            }
        }
    }

    private struct WeeklySensationEntry: Identifiable {
        let week: Date
        let sensation: SensationLevel
        let count: Int
        var id: String { "\(week)-\(sensation.rawValue)" }
        var weekLabel: String { AppDateFormat.dayMonth.string(from: week) }
    }

    /// Même fenêtre fixe de 4 semaines que les autres graphes, empilée par niveau de sensation
    /// (facile en bas, échec en haut) — l'ordre suit l'intensité pour que "monter dans le rouge"
    /// soit visible d'un coup d'œil.
    private var weeklySensationEntries: [WeeklySensationEntry] {
        guard !setEntries.isEmpty else { return [] }
        let grouped = Dictionary(grouping: setEntries) { weekKey($0.date) }

        var entries: [WeeklySensationEntry] = []
        for week in weeksWindow(offsetWindows: sensationWindowOffset) {
            let weekEntries = grouped[week] ?? []
            let countsBySensation = Dictionary(grouping: weekEntries, by: { $0.sensation }).mapValues(\.count)
            for sensation in SensationLevel.allCases {
                entries.append(WeeklySensationEntry(week: week, sensation: sensation, count: countsBySensation[sensation] ?? 0))
            }
        }
        return entries
    }

    private var filteredSensationEntries: [WeeklySensationEntry] {
        weeklySensationEntries.filter { visibleSensations.contains($0.sensation) }
    }

    private var sensationChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Sensations par semaine")
            AppCard {
                if weeklySensationEntries.isEmpty {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else {
                    windowNavigator(weeks: weeksWindow(offsetWindows: sensationWindowOffset), offset: $sensationWindowOffset)
                        .padding(.bottom, 10)

                    FlowLayout(spacing: 6) {
                        ForEach(SensationLevel.allCases, id: \.self) { sensation in
                            legendToggleChip(color: sensation.color, label: sensation.label, isActive: visibleSensations.contains(sensation)) {
                                if visibleSensations.contains(sensation) {
                                    visibleSensations.remove(sensation)
                                } else {
                                    visibleSensations.insert(sensation)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 10)

                    if visibleSensations.isEmpty {
                        Text("Aucun niveau sélectionné")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                    } else {
                        let windowLabels = weeksWindow(offsetWindows: sensationWindowOffset).map { AppDateFormat.dayMonth.string(from: $0) }
                        Chart(filteredSensationEntries) { entry in
                            BarMark(
                                x: .value("Semaine", entry.weekLabel),
                                y: .value("Séries", entry.count),
                                width: .fixed(22)
                            )
                            .foregroundStyle(by: .value("Sensation", entry.sensation.label))
                            .cornerRadius(3)
                        }
                        .chartForegroundStyleScale(
                            domain: SensationLevel.allCases.map(\.label),
                            range: SensationLevel.allCases.map(\.color)
                        )
                        .chartXScale(domain: windowLabels)
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

    private var intensityRanking: [IntensityRankingRow] {
        IntensityRanking.build(setEntries: setEntries, period: intensityPeriod, calendar: calendar)
            .filter { visibleIntensityGroups.contains($0.muscleGroup) }
    }

    private var visibleIntensityRanking: [IntensityRankingRow] {
        Array(intensityRanking.prefix(collapsedExerciseCount))
    }

    private var intensityRankingChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Intensité par exercice")
            AppCard {
                HStack {
                    Spacer(minLength: 0)
                    periodMenu(selection: $intensityPeriod)
                }
                .padding(.bottom, 10)

                FlowLayout(spacing: 6) {
                    ForEach(MuscleGroupStyle.order, id: \.self) { group in
                        legendToggleChip(color: MuscleGroupStyle.color(for: group), label: group, isActive: visibleIntensityGroups.contains(group)) {
                            if visibleIntensityGroups.contains(group) {
                                visibleIntensityGroups.remove(group)
                            } else {
                                visibleIntensityGroups.insert(group)
                            }
                        }
                    }
                }
                .padding(.bottom, 12)

                if visibleIntensityGroups.isEmpty {
                    Text("Aucun groupe sélectionné").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else if intensityRanking.isEmpty {
                    Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                } else {
                    VStack(spacing: 14) {
                        ForEach(visibleIntensityRanking) { row in
                            IntensityRankingRowView(row: row)
                        }
                    }

                    if intensityRanking.count > collapsedExerciseCount {
                        NavigationLink {
                            IntensityRankingView(initialPeriod: intensityPeriod, initialVisibleGroups: visibleIntensityGroups)
                        } label: {
                            Text("Voir tout")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
