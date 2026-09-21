import SwiftUI

/// Ligne "titre, badge de rattachement, date" partagée entre la carte compacte du Tableau de bord
/// et l'écran plein "Voir tout" des bilans.
struct BilanRowView: View {
    let bilan: ArchivedBilan

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bilan.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    if let linkLabel = bilan.linkLabel {
                        Text(linkLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(AppTheme.secondary.opacity(0.15))
                            .foregroundStyle(AppTheme.secondary)
                            .clipShape(Capsule())
                    }
                }
                Text(bilan.importedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "B4AFA6"))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
