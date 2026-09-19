import SwiftUI
import SwiftData

/// Liste des séances d'un jour donné (0, 1 ou plusieurs) — ajout et suppression.
struct DaySessionsView: View {
    let cycle: Cycle
    let weekNumber: Int
    let weekday: Int

    @Environment(\.dismiss) private var dismiss
    @Query private var allSessions: [CycleSession]

    @State private var showingAddSession = false
    @State private var editingSession: CycleSession?

    private var daySessions: [CycleSession] {
        allSessions
            .filter { $0.cycle?.id == cycle.id && $0.weekNumber == weekNumber && $0.weekday == weekday }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if daySessions.isEmpty {
                        AppCard {
                            Text("Repos — aucune séance ce jour-là.")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    } else {
                        AppCard {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(daySessions.enumerated()), id: \.element.id) { index, session in
                                    if index > 0 {
                                        Divider().overlay(AppTheme.border)
                                    }
                                    Button {
                                        editingSession = session
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(topLabel(session))
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(AppTheme.textSecondary)
                                                Text(session.title)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                if session.kind == .musculation && !muscleGroups(session).isEmpty {
                                                    muscleGroupBadges(muscleGroups(session))
                                                        .padding(.top, 6)
                                                }
                                            }
                                            Spacer(minLength: 8)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    AppCard {
                        Button {
                            showingAddSession = true
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppTheme.background)
            .navigationTitle(dayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                EditSessionView(cycle: cycle, weekNumber: weekNumber, weekday: weekday, order: daySessions.count)
            }
            .sheet(item: $editingSession) { session in
                EditSessionView(session: session)
            }
        }
    }

    /// "Musculation · Hypertrophie" — même format que la carte séance de l'accueil.
    private func topLabel(_ session: CycleSession) -> String {
        var parts: [String] = [session.kind.rawValue]
        if let objective = session.objective {
            parts.append(objective.rawValue)
        }
        return parts.joined(separator: " · ")
    }

    /// Groupes musculaires distincts travaillés dans la séance, dans l'ordre de leurs exercices.
    private func muscleGroups(_ session: CycleSession) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for exercise in session.sortedExercises where seen.insert(exercise.muscleGroup).inserted {
            result.append(exercise.muscleGroup)
        }
        return result
    }

    /// Badges colorés (réutilise `MuscleGroupTag`) — 2 max, "+N" pour le reste, pour rester compact
    /// même sur une séance qui touche beaucoup de groupes — pas de limite, retour à la ligne si besoin.
    private func muscleGroupBadges(_ groups: [String]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(groups, id: \.self) { group in
                MuscleGroupTag(group: group)
            }
        }
    }

    private var dayLabel: String {
        Weekday.label(for: weekday)
    }
}
