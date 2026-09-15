import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var allCycles: [Cycle]
    @Query private var allSessions: [CycleSession]
    @Query private var allPrograms: [TrainingProgram]
    @Query(sort: \TransitLog.dateTime, order: .reverse) private var transitLogs: [TransitLog]
    @Query(sort: \MealLog.dateTime, order: .reverse) private var meals: [MealLog]

    @State private var showingMealSheet = false
    @State private var showingTransitSheet = false
    @State private var showingDatePicker = false
    @State private var showingAddAdHocSession = false
    @State private var showingCreateProgram = false
    @State private var createdAdHocSession: CycleSession?
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)

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

                    SectionLabel(text: "Séance du jour")
                    sessionSummaryCard
                    addAdHocSessionButton

                    SectionLabel(text: "Repas")
                    mealCard

                    SectionLabel(text: "Transit")
                    transitCard
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Accueil")
            .sheet(isPresented: $showingMealSheet) { MealEntryView() }
            .sheet(isPresented: $showingTransitSheet) { TransitEntryView() }
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(AppTheme.accent)
                        .clipShape(Capsule())
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
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.accent)
                                .clipShape(Capsule())
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
            case .termine: return .green
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

    private var addAdHocSessionButton: some View {
        Button {
            showingAddAdHocSession = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: "plus")
                Text("Ajouter une séance")
                Spacer()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func sessionCard(_ session: CycleSession) -> some View {
        NavigationLink {
            LogCycleSessionView(session: session)
        } label: {
            AppCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.title)
                            .font(AppTheme.Font.cardTitle)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(summary(for: session))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
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
        var parts: [String] = []
        if session.kind == .musculation {
            let count = session.exercises.count
            parts.append("\(count) exercice\(count > 1 ? "s" : "")")
        }
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
            case .success: return (Color.green.opacity(0.15), Color.green.opacity(0.9))
            case .warning: return (Color.orange.opacity(0.15), Color.orange.opacity(0.9))
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

    private var mealCard: some View {
        AppCard {
            if isToday {
                Button {
                    showingMealSheet = true
                } label: {
                    HStack {
                        Text("Ajouter une prise alimentaire")
                            .foregroundStyle(AppTheme.accent)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            if dayMeals.isEmpty {
                if !isToday {
                    Text("Aucun repas noté").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(dayMeals) { meal in
                        Divider().overlay(AppTheme.border)
                        NavigationLink {
                            MealDetailView(meal: meal)
                        } label: {
                            HStack {
                                Text(meal.dateTime.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(width: 60, alignment: .leading)
                                Text(meal.title)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var transitCard: some View {
        AppCard {
            if isToday {
                Button {
                    showingTransitSheet = true
                } label: {
                    HStack {
                        Text("Ajouter un passage")
                            .foregroundStyle(AppTheme.accent)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            if dayTransitLogs.isEmpty {
                if !isToday {
                    Text("Aucun passage noté").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(dayTransitLogs) { log in
                        Divider().overlay(AppTheme.border)
                        NavigationLink {
                            TransitDetailView(log: log)
                        } label: {
                            HStack {
                                Text(log.dateTime.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(width: 60, alignment: .leading)
                                Text("Type \(log.bristolType.rawValue)")
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
