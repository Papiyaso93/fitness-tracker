import SwiftUI

/// Ligne "nom, ratio X/Y · %, barre colorée" partagée entre la carte compacte du Tableau de bord
/// et l'écran plein "Voir tout".
struct IntensityRankingRowView: View {
    let row: IntensityRankingRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.exerciseName)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 8)
                Text("\(row.nearFailureCount)/\(row.totalCount) · \(Int(row.percentage.rounded()))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: "EFECE5"))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(MuscleGroupStyle.color(for: row.muscleGroup))
                            .frame(width: geometry.size.width * CGFloat(row.percentage / 100))
                    }
            }
            .frame(height: 16)
        }
    }
}
