import SwiftUI

/// Couleur d'une variation de mesure — déterminée par la direction de l'objectif chiffré lié à ce
/// type quand il existe (ex: objectif "Tour de hanches" en baisse → une baisse est positive),
/// jamais par une règle générique par type (baisser n'est pas "toujours bien", ex: tour de bras).
/// Sans objectif de progression clair pour ce type, la variation reste neutre (grise).
enum MeasurementProgressionStyle {
    struct Colors {
        let background: Color
        let text: Color
    }

    static let positive = Colors(background: AppTheme.secondary.opacity(0.13), text: Color(hex: "0F6E56"))
    static let negative = Colors(background: Color(hex: "E24B4A").opacity(0.13), text: Color(hex: "A32D2D"))
    static let neutral = Colors(background: AppTheme.border.opacity(0.5), text: AppTheme.textSecondary)

    static func colors(delta: Double, objective: ProgramObjective?) -> Colors {
        guard delta != 0,
              let objective,
              objective.mode == .progression,
              let start = objective.startValue,
              let target = objective.targetValue,
              target != start
        else { return neutral }

        let goalIsDown = target < start
        let deltaIsDown = delta < 0
        return goalIsDown == deltaIsDown ? positive : negative
    }
}

/// Pastille de variation (flèche + delta) partagée entre l'accueil et le détail d'une mesure —
/// `days` ajoute "(Xj)" quand fourni, omis quand une légende "depuis le [date]" l'affiche déjà à côté.
struct MeasurementDeltaPill: View {
    let delta: Double
    let unit: String
    let colors: MeasurementProgressionStyle.Colors
    var days: Int?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: delta < 0 ? "arrow.down.right" : delta > 0 ? "arrow.up.right" : "minus")
                .font(.system(size: 11, weight: .bold))
            Text("\(delta > 0 ? "+" : "")\(delta.formatted())\(unit)\(days.flatMap { $0 > 0 ? " (\($0)j)" : nil } ?? "")")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(colors.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
