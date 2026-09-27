import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var allCycles: [Cycle]
    @Query private var allSessions: [CycleSession]
    @Query private var allPrograms: [TrainingProgram]
    @Query(sort: \TransitLog.dateTime, order: .reverse) private var transitLogs: [TransitLog]
    @Query(sort: \MealLog.dateTime, order: .reverse) private var meals: [MealLog]
    @Query private var sleepLogs: [SleepLog]
    @Query private var measurements: [BodyMeasurementEntry]
    @Query private var weeklyCheckIns: [WeeklyCheckIn]
    @Query private var allObjectives: [ProgramObjective]

    @State private var showingMealSheet = false
    @State private var showingTransitSheet = false
    @State private var showingSleepSheet: SleepMoment?
    @State private var showingDatePicker = false
    @State private var showingAddAdHocSession = false
    @State private var showingCreateProgram = false
    @State private var showingAddMeasurement = false
    @State private var showingWeeklyCheckInEntry = false
    @State private var createdAdHocSession: CycleSession?
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    /// Non persisté : le contenu du transit redevient masqué à chaque relance de l'app, données
    /// sensibles à ne jamais exposer par défaut (ex: si on montre l'app à quelqu'un).
    @State private var transitRevealed = false

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    /// Le programme dont la période couvre le jour affiché (sans date = toujours actif).
    private var activeProgram: TrainingProgram? {
        allPrograms.first { covers($0, date: selectedDate) }
    }

    private func covers(_ program: TrainingProgram, date: Date) -> Bool {
        switch (program.startDate, program.endDate) {
        case let (start?, end?): return start <= date && date <= end
        case let (start?, nil): return start <= date
        case let (nil, end?): return date <= end
        case (nil, nil): return true
        }
    }

    /// Le cycle du programme actif dont la période couvre le jour affiché.
    private var activeCycle: Cycle? {
        guard let activeProgram else { return nil }
        return allCycles.first {
            $0.program?.id == activeProgram.id && $0.startDate <= selectedDate && selectedDate <= $0.endDate
        }
    }

    /// Le prochain cycle du programme actif (après le jour affiché), s'il y en a un.
    private func upcomingCycle(in program: TrainingProgram) -> Cycle? {
        allCycles
            .filter { $0.program?.id == program.id && $0.startDate > selectedDate }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    private var weekNumber: Int {
        guard let cycle = activeCycle else { return 1 }
        return cycle.weekNumber(for: selectedDate)
    }

    private var weekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var daySessions: [CycleSession] {
        var sessions = allSessions.filter {
            $0.cycle == nil && $0.isAdHoc && $0.adHocDate.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } == true
        }
        if let cycle = activeCycle {
            sessions += allSessions.filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber && $0.weekday == weekday }
        }
        return sessions.sorted { $0.order < $1.order }
    }

    private var dayMeals: [MealLog] {
        meals.filter { Calendar.current.isDate($0.dateTime, inSameDayAs: selectedDate) }
    }

    private var dayTransitLogs: [TransitLog] {
        transitLogs.filter { Calendar.current.isDate($0.dateTime, inSameDayAs: selectedDate) }
    }

    /// Mesures du jour affiché seulement — contrairement à Sommeil/Repas/Transit, une mesure n'a
    /// pas vocation à être renseignée tous les jours, donc pas de "dernière valeur connue" qui
    /// traînerait sur tous les jours suivants : on ne montre la carte que le jour où elle a été
    /// prise, triée dans l'ordre `ObjectiveMetricType.allCases` pour un ordre stable.
    private var dayMeasurements: [BodyMeasurementEntry] {
        measurements
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted {
                (ObjectiveMetricType.allCases.firstIndex(of: $0.type) ?? 0) < (ObjectiveMetricType.allCases.firstIndex(of: $1.type) ?? 0)
            }
    }

    /// La mesure du même type juste avant celle-ci (peu importe le jour) — sert à afficher la
    /// variation ("-2kg vs il y a 3j") plutôt qu'une valeur brute isolée.
    private func previousMeasurement(before entry: BodyMeasurementEntry) -> BodyMeasurementEntry? {
        measurements
            .filter { $0.type == entry.type && $0.date < entry.date }
            .max { $0.date < $1.date }
    }

    private func matchingObjective(for type: ObjectiveMetricType) -> ProgramObjective? {
        allObjectives.first { $0.isMeasurable && $0.metricType == type && $0.targetValue != nil }
    }

    private func measurementBadge(_ type: ObjectiveMetricType) -> String {
        switch type {
        case .poids: return "kg"
        case .masseGrasse: return "%"
        case .vo2max: return "vo2"
        case .nombreDePas: return "pas"
        case .autre: return "?"
        default: return "cm"
        }
    }

    /// Dimanche de la semaine contenant `selectedDate` — clé utilisée pour retrouver/créer le
    /// `WeeklyCheckIn` de la semaine en cours (convention `Calendar` 1=dimanche, cf. `Weekday`).
    private var currentWeekSunday: Date {
        let start = Calendar.current.startOfDay(for: selectedDate)
        let weekdayOffset = Calendar.current.component(.weekday, from: start) - 1
        return Calendar.current.date(byAdding: .day, value: -weekdayOffset, to: start) ?? start
    }

    private var existingWeeklyCheckIn: WeeklyCheckIn? {
        weeklyCheckIns.first { Calendar.current.isDate($0.weekDate, inSameDayAs: currentWeekSunday) }
    }

    private var daySleepLog: SleepLog? {
        sleepLogs.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }
    }

    private var previousDaySleepLog: SleepLog? {
        guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return nil }
        return sleepLogs.first { Calendar.current.isDate($0.day, inSameDayAs: previousDay) }
    }

    /// Nuit = coucher de la veille → réveil du jour affiché. Pas de badge si le coucher de la
    /// veille n'a pas été renseigné : rien à calculer, on n'affiche pas de placeholder.
    private var sleepDurationLabel: String? {
        guard let bedTime = previousDaySleepLog?.bedTime, let wakeTime = daySleepLog?.wakeTime else { return nil }
        let minutesTotal = Int(wakeTime.timeIntervalSince(bedTime) / 60)
        guard minutesTotal > 0 else { return nil }
        return "\(minutesTotal / 60)h\(String(format: "%02d", minutesTotal % 60)) de sommeil"
    }

    /// Le prochain programme à venir après le jour affiché — utilisé seulement quand aucun
    /// programme n'est actif ce jour-là.
    private var upcomingProgram: TrainingProgram? {
        allPrograms
            .filter { ($0.startDate ?? .distantPast) > selectedDate }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dayNavigator

                    if let activeProgram {
                        if let cycle = activeCycle {
                            activeCycleCard(cycle)
                        } else {
                            programActiveNoCycleCard(activeProgram, upcomingCycle: upcomingCycle(in: activeProgram))
                        }
                    } else if let upcoming = upcomingProgram {
                        upcomingProgramCard(upcoming)
                    } else {
                        noProgramCard
                    }

                    weeklyCheckInSection

                    if daySessions.isEmpty && activeCycle == nil {
                        SectionLabel(text: "Séance du jour")
                        addAdHocSessionCard
                    } else {
                        sessionSectionHeader
                        sessionSummaryCard
                    }

                    SectionLabel(text: "Sommeil")
                    sleepCard

                    if isToday && dayMeals.isEmpty {
                        SectionLabel(text: "Repas")
                        addMealCard
                    } else {
                        mealSectionHeader
                        mealCard
                    }

                    if isToday && dayTransitLogs.isEmpty {
                        SectionLabel(text: "Transit")
                        addTransitCard
                    } else {
                        transitSectionHeader
                        transitCard
                    }

                    if isToday && dayMeasurements.isEmpty {
                        SectionLabel(text: "Mesures")
                        addMeasurementCard
                    } else {
                        measurementSectionHeader
                        measurementCard
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Accueil")
            .sheet(isPresented: $showingMealSheet) { MealEntryView() }
            .sheet(isPresented: $showingTransitSheet) { TransitEntryView() }
            .sheet(item: $showingSleepSheet) { moment in
                SleepEntryView(day: selectedDate, moment: moment)
            }
            .sheet(isPresented: $showingAddAdHocSession) {
                AddAdHocSessionView(cycle: activeCycle, date: selectedDate) { session in
                    createdAdHocSession = session
                }
            }
            .navigationDestination(item: $createdAdHocSession) { session in
                LogCycleSessionView(session: session)
            }
            .sheet(isPresented: $showingCreateProgram) {
                CreateProgramView()
            }
            .sheet(isPresented: $showingAddMeasurement) {
                AddBodyMeasurementView()
            }
            .sheet(isPresented: $showingWeeklyCheckInEntry) {
                WeeklyCheckInEntryView(weekDate: currentWeekSunday)
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: { selectedDate },
                            set: { newValue in
                                selectedDate = Calendar.current.startOfDay(for: newValue)
                                showingDatePicker = false
                            }
                        ),
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(AppTheme.accent)
                    .padding()
                    .navigationTitle("Choisir une date")
                    .navigationBarTitleDisplayMode(.inline)
                    .presentationDetents([.medium])
                }
            }
        }
    }

    private var dayNavigator: some View {
        HStack(spacing: 14) {
            Spacer(minLength: 0)
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
            }
            Button {
                showingDatePicker = true
            } label: {
                Text(dayLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isToday)
            .opacity(isToday ? 0.3 : 1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppTheme.accent)
        .frame(maxWidth: .infinity)
    }

    private var dayLabel: String {
        if isToday { return "Aujourd'hui" }
        return AppDateFormat.weekdayDayMonth.string(from: selectedDate).capitalized
    }

    private var noProgramCard: some View {
        AppCard {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppTheme.border.opacity(0.5)).frame(width: 40, height: 40)
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                VStack(spacing: 4) {
                    Text("Aucun programme en cours")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Crée un programme pour planifier tes séances et suivre tes objectifs.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Button {
                    showingCreateProgram = true
                } label: {
                    Text("Créer un programme")
                        .compactAccentButtonStyle()
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private func upcomingProgramCard(_ program: TrainingProgram) -> some View {
        AppCard {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(AppTheme.border.opacity(0.5)).frame(width: 36, height: 36)
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pas de programme en cours")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    if let startDate = program.startDate {
                        Text("« \(program.title) » commence le \(formatted(startDate))")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        AppDateFormat.dayFullMonth.string(from: date)
    }

    private func programActiveNoCycleCard(_ program: TrainingProgram, upcomingCycle: Cycle?) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(program.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("— en cours")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    if let upcomingCycle {
                        Text("Prochain cycle « \(upcomingCycle.name) » le \(formatted(upcomingCycle.startDate))")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Text("Aucun cycle configuré pour ce programme.")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                        NavigationLink {
                            ProgramDetailView(program: program)
                        } label: {
                            Text("Ajouter un cycle")
                                .compactAccentButtonStyle(fontSize: 13, verticalPadding: 7, horizontalPadding: 14)
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func activeCycleCard(_ cycle: Cycle) -> some View {
        NavigationLink {
            CyclePlanningView(cycle: cycle)
        } label: {
            AppCard {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.accent)
                        Text(cycle.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Spacer()
                    cycleStatusTag(cycle.status)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.border.opacity(0.5)).frame(height: 5)
                        Capsule().fill(AppTheme.accent).frame(width: geometry.size.width * cycleProgress(cycle), height: 5)
                    }
                }
                .frame(height: 5)
                HStack {
                    Text("Semaine \(weekNumber) / \(cycle.weekCount)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    if !cycle.objectifsPrincipaux.isEmpty {
                        Text(cycle.objectifsPrincipaux.map(\.rawValue).joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func cycleProgress(_ cycle: Cycle) -> Double {
        guard cycle.weekCount > 0 else { return 0 }
        return min(1, max(0, Double(weekNumber) / Double(cycle.weekCount)))
    }

    private func cycleStatusTag(_ status: ProgramStatus) -> some View {
        let color: Color = {
            switch status {
            case .aVenir: return AppTheme.textSecondary
            case .enCours: return AppTheme.accent
            case .termine: return AppTheme.secondary
            }
        }()
        return Text(status.rawValue)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var sessionSummaryCard: some View {
        if daySessions.isEmpty {
            if activeCycle != nil {
                VStack(spacing: 8) {
                    Text("Pas de séance prévue. Repose-toi.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(daySessions) { session in
                    sessionCard(session)
                }
            }
        }
    }

    private var sessionSectionHeader: some View {
        HStack {
            SectionLabel(text: "Séance du jour")
            Spacer()
            Button {
                showingAddAdHocSession = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.trailing, 4)
        }
    }

    private var addAdHocSessionCard: some View {
        AppCard {
            Button {
                showingAddAdHocSession = true
            } label: {
                HStack {
                    Text("Ajouter une séance")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private func sessionCard(_ session: CycleSession) -> some View {
        NavigationLink {
            LogCycleSessionView(session: session)
        } label: {
            AppCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary(for: session))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(session.title)
                            .font(AppTheme.Font.cardTitle)
                            .foregroundStyle(AppTheme.textPrimary)
                        statusTag(for: session)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "3 exercices · Hypertrophie"
    private func summary(for session: CycleSession) -> String {
        var parts: [String] = [session.kind.rawValue]
        if let objective = session.objective {
            parts.append(objective.rawValue)
        }
        return parts.joined(separator: " · ")
    }

    private enum TagColor { case success, warning, danger, neutral, accentTag, pro }

    @ViewBuilder
    private func statusTag(for session: CycleSession) -> some View {
        if let completion = session.completion {
            HStack(spacing: 6) {
                if completion.endTime != nil {
                    tag("Terminée", color: .success)
                    if completion.isAdapted {
                        tag("Séance adaptée", color: .warning)
                    }
                } else if completion.startTime != nil {
                    tag("En cours", color: .accentTag)
                }
                if session.isAdHoc {
                    tag("Hors programme", color: .pro)
                }
            }
        } else {
            HStack(spacing: 6) {
                tag(isToday ? "À faire" : "Manquée", color: isToday ? .neutral : .danger)
                if session.isAdHoc {
                    tag("Hors programme", color: .pro)
                }
            }
        }
    }

    private func tag(_ text: String, color: TagColor) -> some View {
        let (bg, fg): (Color, Color) = {
            switch color {
            case .success: return (AppTheme.secondary.opacity(0.15), AppTheme.secondary)
            case .warning: return (Color.yellow.opacity(0.2), Color(hex: "8A6D00"))
            case .danger: return (Color.red.opacity(0.15), Color.red.opacity(0.9))
            case .neutral: return (AppTheme.border.opacity(0.5), AppTheme.textSecondary)
            case .accentTag: return (AppTheme.accent.opacity(0.15), AppTheme.accent)
            case .pro: return (Color.purple.opacity(0.15), Color.purple.opacity(0.9))
            }
        }()
        return Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var weeklyCheckInSection: some View {
        // Visible sur tout dimanche navigué — passé, présent, jamais futur puisque la navigation
        // ne dépasse pas aujourd'hui — pour pouvoir rattraper un bilan oublié, comme on peut
        // toujours ajouter une séance passée.
        if weekday == 1 {
            if let existing = existingWeeklyCheckIn {
                SectionLabel(text: "Bilan hebdomadaire")
                NavigationLink {
                    WeeklyCheckInDetailView(checkIn: existing)
                } label: {
                    AppCard {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 19))
                                .foregroundStyle(AppTheme.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bilan de la semaine fait")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Semaine du \(formatted(existing.weekDate))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "B4AFA6"))
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                SectionLabel(text: "Bilan hebdomadaire")
                AppCard {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                        Text("Bilan hebdomadaire")
                            .font(AppTheme.Font.cardTitle)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Text("C'est dimanche — prends deux minutes pour faire le point sur ta semaine.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        showingWeeklyCheckInEntry = true
                    } label: {
                        Text("Commencer le bilan")
                            .primaryButtonStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var measurementSectionHeader: some View {
        HStack {
            SectionLabel(text: "Mesures")
            Spacer()
            if isToday {
                Button {
                    showingAddMeasurement = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.trailing, 4)
            }
        }
    }

    private var addMeasurementCard: some View {
        AppCard {
            Button {
                showingAddMeasurement = true
            } label: {
                HStack {
                    Text("Ajouter une mesure")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private var measurementCard: some View {
        AppCard {
            if dayMeasurements.isEmpty {
                Text("Aucune mesure ce jour-là")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
            VStack(spacing: 0) {
                ForEach(Array(dayMeasurements.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider().overlay(AppTheme.border) }
                    NavigationLink {
                        MeasurementDetailView(type: entry.type)
                    } label: {
                        HStack(spacing: 10) {
                            Text(measurementBadge(entry.type))
                                .font(.system(size: 9, weight: .bold))
                                .frame(width: 26, height: 26)
                                .foregroundStyle(Color(hex: "993C1D"))
                                .background(AppTheme.accent.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.type.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                let previous = previousMeasurement(before: entry)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(entry.value.formatted())\(entry.type.unit)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    if let previous {
                                        let delta = entry.value - previous.value
                                        MeasurementDeltaPill(
                                            delta: delta,
                                            unit: entry.type.unit,
                                            colors: MeasurementProgressionStyle.colors(delta: delta, objective: matchingObjective(for: entry.type))
                                        )
                                    }
                                }
                                if let previous {
                                    Text("depuis le \(AppDateFormat.dayFullMonth.string(from: previous.date))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            }
        }
    }

    private var sleepCard: some View {
        AppCard {
            VStack(spacing: 0) {
                sleepRow(moment: .reveil, icon: "sunrise", time: daySleepLog?.wakeTime, energy: daySleepLog?.wakeEnergy, stomach: daySleepLog?.wakeStomach, durationLabel: sleepDurationLabel)
                Divider().overlay(AppTheme.border)
                sleepRow(moment: .coucher, icon: "moon", time: daySleepLog?.bedTime, energy: daySleepLog?.bedEnergy, stomach: daySleepLog?.bedStomach, durationLabel: nil)
            }
        }
    }

    @ViewBuilder
    private func sleepRow(moment: SleepMoment, icon: String, time: Date?, energy: EnergyLevel?, stomach: StomachState?, durationLabel: String?) -> some View {
        let isFilled = time != nil
        Group {
            if isFilled, let log = daySleepLog {
                NavigationLink {
                    SleepDetailView(log: log, moment: moment)
                } label: {
                    sleepRowContent(moment: moment, icon: icon, time: time, energy: energy, stomach: stomach, isFilled: true, durationLabel: durationLabel)
                }
                .buttonStyle(.plain)
            } else if isToday {
                Button { showingSleepSheet = moment } label: {
                    sleepRowContent(moment: moment, icon: icon, time: time, energy: energy, stomach: stomach, isFilled: false, durationLabel: durationLabel)
                }
                .buttonStyle(.plain)
            } else {
                sleepRowContent(moment: moment, icon: icon, time: time, energy: energy, stomach: stomach, isFilled: false, durationLabel: durationLabel)
            }
        }
    }

    private func sleepRowContent(moment: SleepMoment, icon: String, time: Date?, energy: EnergyLevel?, stomach: StomachState?, isFilled: Bool, durationLabel: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle((isFilled || isToday) ? AppTheme.textSecondary : AppTheme.textSecondary.opacity(0.6))
                .frame(width: 20)
            if isFilled, let time {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(moment.title) · \(time.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(energy?.label ?? "") · \(stomach?.label ?? "")")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    if let durationLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "bed.double.fill")
                                .font(.system(size: 10))
                            Text(durationLabel)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.background)
                        .clipShape(Capsule())
                        .padding(.top, 2)
                    }
                }
            } else if isToday {
                Text(moment.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
            } else {
                Text("\(moment.title) non renseigné")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if isFilled {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else if isToday {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var mealSectionHeader: some View {
        HStack {
            SectionLabel(text: "Repas")
            Spacer()
            if isToday {
                Button {
                    showingMealSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.trailing, 4)
            }
        }
    }

    private var addMealCard: some View {
        AppCard {
            Button {
                showingMealSheet = true
            } label: {
                HStack {
                    Text("Ajouter une prise alimentaire")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private var mealCard: some View {
        AppCard {
            if dayMeals.isEmpty {
                Text("Aucun repas noté").font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(dayMeals) { meal in
                        if meal.id != dayMeals.first?.id {
                            Divider().overlay(AppTheme.border)
                        }
                        NavigationLink {
                            MealDetailView(meal: meal)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: meal.sensation.icon)
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 26, height: 26)
                                    .foregroundStyle(meal.sensation.categoryColor.text)
                                    .background(meal.sensation.categoryColor.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(meal.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(meal.sensation.rawValue)
                                        .font(.system(size: 11))
                                        .foregroundStyle(meal.sensation.categoryColor.text)
                                }
                                Spacer()
                                Text(meal.dateTime.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var transitSectionHeader: some View {
        HStack {
            SectionLabel(text: "Transit")
            Spacer()
            if transitRevealed {
                Button {
                    transitRevealed = false
                } label: {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.trailing, isToday ? 14 : 4)
            }
            if isToday {
                Button {
                    showingTransitSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.trailing, 4)
            }
        }
    }

    private var addTransitCard: some View {
        AppCard {
            Button {
                showingTransitSheet = true
            } label: {
                HStack {
                    Text("Ajouter un passage")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private var transitCard: some View {
        ZStack {
            AppCard {
                if dayTransitLogs.isEmpty {
                    Text("Aucun passage noté").font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary)
                } else {
                    transitLogsList
                }
            }
            .blur(radius: (dayTransitLogs.isEmpty || transitRevealed) ? 0 : 8)
            .allowsHitTesting(dayTransitLogs.isEmpty || transitRevealed)

            if !dayTransitLogs.isEmpty && !transitRevealed {
                Button {
                    transitRevealed = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.surface)
                            .overlay(Circle().stroke(AppTheme.border, lineWidth: 0.5))
                            .clipShape(Circle())
                        Text("Afficher")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var transitLogsList: some View {
        VStack(spacing: 0) {
            ForEach(dayTransitLogs) { log in
                        if log.id != dayTransitLogs.first?.id {
                            Divider().overlay(AppTheme.border)
                        }
                        NavigationLink {
                            TransitDetailView(log: log)
                        } label: {
                            HStack(spacing: 10) {
                                Text("\(log.bristolType.rawValue)")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 26, height: 26)
                                    .foregroundStyle(log.bristolType.categoryColor.text)
                                    .background(log.bristolType.categoryColor.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(log.bristolType.shortDescription)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(log.bristolType.category)
                                        .font(.system(size: 11))
                                        .foregroundStyle(log.bristolType.categoryColor.text)
                                }
                                Spacer()
                                Text(log.dateTime.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
            }
        }
    }
}
