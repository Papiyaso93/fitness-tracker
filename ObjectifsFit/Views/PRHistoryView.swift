import SwiftUI
import SwiftData

/// Écran "Voir tout" de l'historique des records — la liste complète des records battus pour un
/// exercice, contrairement à la carte compacte du Tableau de bord qui ne montre que les 4 derniers.
struct PRHistoryView: View {
    @Query private var setEntries: [PlannedSetEntry]

    let exerciseName: String

    private var history: [PRHistoryEntry] {
        PRHistoryBuilder.build(setEntries: setEntries, exerciseName: exerciseName)
    }

    var body: some View {
        ScrollView {
            AppCard {
                if history.isEmpty {
                    Text("Pas de charge enregistrée pour cet exercice")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Divider().overlay(AppTheme.border) }
                            PRHistoryRowView(entry: entry)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
