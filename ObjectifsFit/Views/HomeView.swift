import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var allCycles: [Cycle]
    @Query private var allSessions: [CycleSession]
    @Query(sort: \TransitLog.dateTime, order: .reverse) private var transitLogs: [TransitLog]
    @Query(sort: \MealLog.dateTime, order: .reverse) private var meals: [MealLog]

    @State private var showingMealSheet = false
    @State private var showingTransitSheet = false
    @State private var showingDatePicker = false
    @State private var showingAddAdHocSession = false
    @State private var createdAdHocSession: CycleSession?
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    /// Le cycle (nouveau système Programme/Cycle) dont la période couvre le jour affiché.
    private var activeCycle: Cycle? {
        allCycles.first {
            $0.program != nil && $0.startDate <= selectedDate && selectedDate <= $0.endDate
        }
    }

    private var weekNumber: Int {
        guard let cycle = activeCycle else { return 1 }
        return cycle.weekNumber(for: selectedDate)
    }

    private var weekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var daySessions: [CycleSession] {
        guard let cycle = activeCycle else { return [] }
        return allSessions
            .filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber && $0.weekday == weekday }
            .sorted { $0.order < $1.order }
    }

    private var dayMeals: [MealLog] {
        meals.filter { Calendar.current.isDate($0.dateTime, inSameDayAs: selectedDate) }
    }

    private var dayTransitLogs: [TransitLog] {
        transitLogs.filter { Calendar.current.isDate($0.dateTime, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dayNavigator

                    if let cycle = activeCycle {
                        activeCycleCard(cycle)
                    }
                    SectionLabel(text: "Séance du jour")
                    sessionSummaryCard
                    if activeCycle != nil {
                        addAdHocSessionButton
                    }

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
                if let cycle = activeCycle {
                    AddAdHocSessionView(cycle: cycle, date: selectedDate) { session in
                        createdAdHocSession = session
                    }
                }
            }
            .navigationDestination(item: $createdAdHocSession) { session in
                LogCycleSessionView(session: session)
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMM"
        return formatter.string(from: selectedDate).capitalized
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
        if activeCycle == nil {
            AppCard {
                Text("Pas de cycle actif").foregroundStyle(AppTheme.textSecondary)
            }
        } else if daySessions.isEmpty {
            VStack(spacing: 8) {
                Text("Pas de séance prévue. Repose-toi.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
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
