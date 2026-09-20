import SwiftUI

/// Pastille de légende tappable, utilisée comme filtre sur les graphes du Tableau de bord —
/// active = pastille teintée, inactive = grisée. Partagée entre tous les graphes filtrables pour
/// garder le même geste d'interaction partout (tap = inclure/exclure).
func legendToggleChip(color: Color, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
        }
        .foregroundStyle(isActive ? color : AppTheme.textSecondary.opacity(0.5))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(isActive ? color.opacity(0.12) : Color.clear)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
}
