import SwiftUI
import SwiftData

/// Planning en lecture d'un cycle — s'ouvre sur la semaine en cours, navigable sur toute la durée
/// du cycle. Accessible depuis la carte de cycle actif sur l'Accueil.
struct CyclePlanningView: View {
    let cycle: Cycle

    @Query private var allSessions: [CycleSession]
    @State private var weekNumber: Int

    init(cycle: Cycle) {
        self.cycle = cycle
        _weekNumber = State(initialValue: max(1, min(cycle.weekNumber(for: .now), cycle.weekCount)))
    }

    private var calendar: Calendar { Calendar.current }

    private func date(for weekday: Int) -> Date? {
        cycle.date(forWeek: weekNumber, weekday: weekday)
    }

    private func sessions(for weekday: Int) -> [CycleSession] {
        allSessions
            .filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber && $0.weekday == weekday }
            .sorted { $0.order < $1.order }
    }

    private func dayLabel(_ date: Date) -> String {
        AppDateFormat.dayMonth.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                weekNavigator

                AppCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(Weekday.ordered.enumerated()), id: \.element.weekday) { index, day in
                            if index > 0 { Divider().overlay(AppTheme.border) }
                            dayRow(weekday: day.weekday, label: day.label)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle(cycle.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weekNavigator: some View {
        HStack {
            Button {
                weekNumber = max(1, weekNumber - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(weekNumber <= 1)
            .opacity(weekNumber <= 1 ? 0.3 : 1)

            Spacer()

            VStack(spacing: 2) {
                Text("Semaine \(weekNumber)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("sur \(cycle.weekCount)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                weekNumber = min(cycle.weekCount, weekNumber + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(weekNumber >= cycle.weekCount)
            .opacity(weekNumber >= cycle.weekCount ? 0.3 : 1)
        }
        .foregroundStyle(AppTheme.accent)
    }

    @ViewBuilder
    private func dayRow(weekday: Int, label: String) -> some View {
        let daySessions = sessions(for: weekday)
        let isToday = date(for: weekday).map { calendar.isDateInToday($0) } ?? false

        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                if let date = date(for: weekday) {
                    Text(isToday ? "Aujourd'hui" : dayLabel(date))
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(width: 74, alignment: .leading)

            if daySessions.isEmpty {
                Text("Repos")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 6) {
                    ForEach(daySessions) { session in
                        NavigationLink {
                            LogCycleSessionView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text([session.kind.rawValue, session.objective?.rawValue].compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(isToday ? AppTheme.accent.opacity(0.1) : AppTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}
