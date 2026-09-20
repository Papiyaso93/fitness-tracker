import SwiftUI

/// Ligne "nom + barre proportionnelle + compte" partagée entre la carte compacte du Tableau de
/// bord et l'écran plein "Voir tout" — un exercice jamais fait sur la période (count 0) reste
/// visible mais atténué, plutôt que d'être simplement absent de la liste.
struct ExerciseRankingRowView: View {
    let row: ExerciseRankingRow
    let maxCount: Int

    private var isNeverDone: Bool { row.count == 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.exerciseName)
                .font(.system(size: 13))
                .foregroundStyle(isNeverDone ? AppTheme.textSecondary : AppTheme.textPrimary)
            HStack(spacing: 8) {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: "EFECE5"))
                        .overlay(alignment: .leading) {
                            if !isNeverDone {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(MuscleGroupStyle.color(for: row.muscleGroup))
                                    .frame(width: geometry.size.width * CGFloat(row.count) / CGFloat(maxCount))
                            }
                        }
                }
                .frame(height: 16)
                Text(isNeverDone ? "Jamais" : "\(row.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(minWidth: 22, alignment: .trailing)
            }
        }
    }
}
