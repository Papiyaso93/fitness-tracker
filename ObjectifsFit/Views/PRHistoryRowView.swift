import SwiftUI

/// Ligne "poids × reps, delta, date" partagée entre la carte compacte du Tableau de bord et
/// l'écran plein "Voir tout".
struct PRHistoryRowView: View {
    let entry: PRHistoryEntry

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(WeightFormat.string(entry.weight))kg")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                + Text(" × \(entry.reps) reps")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 8)
            if let delta = entry.delta {
                Text("+\(WeightFormat.string(delta))kg")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(AppTheme.secondary.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Text("Premier")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(hex: "F1EFE8"))
                    .clipShape(Capsule())
            }
            HStack(spacing: 3) {
                Image(systemName: "calendar")
                    .font(.system(size: 9))
                Text(AppDateFormat.dayMonth.string(from: entry.date))
                    .font(.system(size: 11))
            }
            .foregroundStyle(AppTheme.textSecondary)
            .frame(width: 75, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}
