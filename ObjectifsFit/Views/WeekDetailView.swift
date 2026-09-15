import SwiftUI
import SwiftData

/// Détail d'une semaine du cycle — les 7 jours, "Repos" par défaut, plusieurs séances possibles
/// par jour.
struct WeekDetailView: View {
    let cycle: Cycle
    let weekNumber: Int

    private struct WeekdaySelection: Identifiable { let weekday: Int; var id: Int { weekday } }

    @Environment(\.modelContext) private var context
    @Query private var allSessions: [CycleSession]
    @State private var selectedWeekday: WeekdaySelection?
    @State private var showingSwapDays = false

    private var currentWeekSessions: [CycleSession] {
        allSessions.filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber }
    }

    private var previousWeekSessions: [CycleSession] {
        allSessions.filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber - 1 }
    }

    private var canDuplicatePreviousWeek: Bool {
        weekNumber > 1 && currentWeekSessions.isEmpty && !previousWeekSessions.isEmpty
    }

    /// Lundi en premier, comme le reste de l'app (WeeklySchedule) — 2=Lundi ... 1=Dimanche (Calendar).
    private let orderedWeekdays: [(weekday: Int, label: String)] = [
        (2, "Lundi"), (3, "Mardi"), (4, "Mercredi"), (5, "Jeudi"), (6, "Vendredi"), (7, "Samedi"), (1, "Dimanche")
    ]

    private func sessions(for weekday: Int) -> [CycleSession] {
        allSessions
            .filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber && $0.weekday == weekday }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            if canDuplicatePreviousWeek {
                Button {
                    duplicatePreviousWeek()
                } label: {
                    Label("Dupliquer la semaine précédente", systemImage: "doc.on.doc")
                }
            }
            ForEach(orderedWeekdays, id: \.weekday) { day in
                Button {
                    selectedWeekday = WeekdaySelection(weekday: day.weekday)
                } label: {
                    HStack {
                        Text(day.label)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(summary(for: day.weekday))
                            .foregroundStyle(AppTheme.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                showingSwapDays = true
            } label: {
                Label("Permuter deux jours", systemImage: "arrow.left.arrow.right")
            }
        }
        .navigationTitle("Semaine \(weekNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWeekday) { selection in
            DaySessionsView(cycle: cycle, weekNumber: weekNumber, weekday: selection.weekday)
        }
        .sheet(isPresented: $showingSwapDays) {
            SwapDaysView(cycle: cycle, weekNumber: weekNumber)
        }
    }

    private func summary(for weekday: Int) -> String {
        let daySessions = sessions(for: weekday)
        return daySessions.isEmpty ? "Repos" : daySessions.map(\.title).joined(separator: ", ")
    }

    /// Copie chaque séance (et ses exercices) de la semaine précédente vers celle-ci, à l'identique.
    private func duplicatePreviousWeek() {
        for source in previousWeekSessions {
            let copy = CycleSession(
                weekNumber: weekNumber,
                weekday: source.weekday,
                title: source.title,
                kind: source.kind,
                objective: source.objective,
                sessionDescription: source.sessionDescription,
                order: source.order
            )
            copy.cycle = cycle
            context.insert(copy)

            for exercise in source.sortedExercises {
                let exerciseCopy = PlannedExercise(
                    muscleGroup: exercise.muscleGroup,
                    exerciseName: exercise.exerciseName,
                    technique: exercise.technique,
                    resistanceMode: exercise.resistanceMode,
                    targetSets: exercise.targetSets,
                    targetWeight: exercise.targetWeight,
                    isRepsRange: exercise.isRepsRange,
                    targetRepsMin: exercise.targetRepsMin,
                    targetRepsMax: exercise.targetRepsMax,
                    order: exercise.order
                )
                exerciseCopy.session = copy
                context.insert(exerciseCopy)
            }
        }
    }
}
