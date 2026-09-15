import SwiftUI
import SwiftData

/// Liste des séances d'un jour donné (0, 1 ou plusieurs) — ajout et suppression.
struct DaySessionsView: View {
    let cycle: Cycle
    let weekNumber: Int
    let weekday: Int

    @Environment(\.modelContext) private var context
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
            List {
                if daySessions.isEmpty {
                    Text("Repos — aucune séance ce jour-là.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ForEach(daySessions) { session in
                    Button {
                        editingSession = session
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .fontWeight(.medium)
                                Text(subtitleLabel(session))
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(daySessions[index])
                    }
                }

                Button {
                    showingAddSession = true
                } label: {
                    Label("Ajouter une séance", systemImage: "plus.circle")
                }
            }
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

    /// "3 exercices · Hypertrophie" — texte discret, distinct des tags de statut (pilule colorée)
    /// utilisés ailleurs, pour ne pas les confondre une fois que l'Accueil affichera les deux.
    private func subtitleLabel(_ session: CycleSession) -> String {
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

    private var dayLabel: String {
        let names: [Int: String] = [1: "Dimanche", 2: "Lundi", 3: "Mardi", 4: "Mercredi", 5: "Jeudi", 6: "Vendredi", 7: "Samedi"]
        return names[weekday] ?? ""
    }
}
