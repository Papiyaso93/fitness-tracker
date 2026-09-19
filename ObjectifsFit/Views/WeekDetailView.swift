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

    private func sessions(for weekday: Int) -> [CycleSession] {
        allSessions
            .filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber && $0.weekday == weekday }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if canDuplicatePreviousWeek {
                    AppCard {
                        Button {
                            duplicatePreviousWeek()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                Text("Dupliquer la semaine précédente")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(Weekday.ordered.enumerated()), id: \.element.weekday) { index, day in
                            if index > 0 {
                                Divider().overlay(AppTheme.border)
                            }
                            Button {
                                selectedWeekday = WeekdaySelection(weekday: day.weekday)
                            } label: {
                                HStack {
                                    Text(day.label)
                                        .font(.system(size: 15))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text(summary(for: day.weekday))
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                AppCard {
                    Button {
                        showingSwapDays = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.arrow.right")
                            Text("Permuter deux jours")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.background)
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
