import SwiftUI
import SwiftData

/// Écran "Voir tout" du classement d'intensité — la liste complète, contrairement à la carte
/// compacte du Tableau de bord qui ne montre que le top 6. Porte aussi l'explication de la règle
/// de calcul, qui casserait la cohérence visuelle des cartes compactes du Tableau de bord.
struct IntensityRankingView: View {
    @Query private var setEntries: [PlannedSetEntry]

    @State private var period: ExercisePeriod
    @State private var visibleGroups: Set<String>

    init(initialPeriod: ExercisePeriod = .fourWeeks, initialVisibleGroups: Set<String> = Set(MuscleGroupStyle.order)) {
        _period = State(initialValue: initialPeriod)
        _visibleGroups = State(initialValue: initialVisibleGroups)
    }

    private var ranking: [IntensityRankingRow] {
        IntensityRanking.build(setEntries: setEntries, period: period)
            .filter { visibleGroups.contains($0.muscleGroup) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Le ratio correspond au nombre de séries notées très difficiles ou à l'échec sur le nombre de séries totales.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)

                HStack {
                    Spacer(minLength: 0)
                    Menu {
                        ForEach(ExercisePeriod.allCases, id: \.self) { option in
                            Button {
                                period = option
                            } label: {
                                if period == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(period.rawValue)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                    }
                }

                FlowLayout(spacing: 6) {
                    ForEach(MuscleGroupStyle.order, id: \.self) { group in
                        legendToggleChip(color: MuscleGroupStyle.color(for: group), label: group, isActive: visibleGroups.contains(group)) {
                            if visibleGroups.contains(group) {
                                visibleGroups.remove(group)
                            } else {
                                visibleGroups.insert(group)
                            }
                        }
                    }
                }

                AppCard {
                    if visibleGroups.isEmpty {
                        Text("Aucun groupe sélectionné").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                    } else if ranking.isEmpty {
                        Text("Pas encore de données").font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(ranking) { row in
                                IntensityRankingRowView(row: row)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Intensité par exercice")
        .navigationBarTitleDisplayMode(.inline)
    }
}
