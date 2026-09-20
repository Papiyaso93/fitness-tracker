import SwiftUI
import SwiftData

/// Écran "Voir tout" du classement par exercice — la bibliothèque complète (y compris les
/// exercices jamais faits sur la période, affichés atténués en bas), contrairement à la carte
/// compacte du Tableau de bord qui ne montre que le top 6.
struct ExerciseFrequencyView: View {
    @Query private var setEntries: [PlannedSetEntry]
    @Query(sort: \ExerciseDefinition.name) private var exerciseLibrary: [ExerciseDefinition]

    @State private var period: ExercisePeriod
    @State private var visibleGroups: Set<String> = Set(MuscleGroupStyle.order)

    init(initialPeriod: ExercisePeriod = .fourWeeks, initialVisibleGroups: Set<String> = Set(MuscleGroupStyle.order)) {
        _period = State(initialValue: initialPeriod)
        _visibleGroups = State(initialValue: initialVisibleGroups)
    }

    private var ranking: [ExerciseRankingRow] {
        ExerciseRanking.build(setEntries: setEntries, exerciseLibrary: exerciseLibrary, period: period)
            .filter { visibleGroups.contains($0.muscleGroup) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                        Text("Aucun groupe sélectionné")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        let maxCount = max(ranking.first?.count ?? 1, 1)
                        VStack(spacing: 12) {
                            ForEach(ranking) { row in
                                ExerciseRankingRowView(row: row, maxCount: maxCount)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Séries par exercice")
        .navigationBarTitleDisplayMode(.inline)
    }
}
