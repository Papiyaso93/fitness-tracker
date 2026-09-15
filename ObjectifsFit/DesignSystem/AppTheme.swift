import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Design system "Slate & Cobalt" — fond gris clair, cartes blanches, accent bleu franc.
/// Mode sombre à construire plus tard (cf. décision produit).
enum AppTheme {
    static let background = Color(hex: "F4F4F2")
    static let surface = Color.white
    static let border = Color(hex: "DEDEDA")
    static let accent = Color(hex: "1B5CE0")
    static let textPrimary = Color(hex: "1A1C1E")
    static let textSecondary = Color(hex: "6B6E72")

    static let cardRadius: CGFloat = 14
    static let cardPadding: CGFloat = 14

    enum Font {
        static let statValue = SwiftUI.Font.system(size: 26, weight: .semibold, design: .rounded)
        static let statLabel = SwiftUI.Font.system(size: 12, weight: .medium)
        static let cardTitle = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let sectionHeader = SwiftUI.Font.system(size: 12, weight: .semibold)
    }
}

/// Style de carte réutilisable : fond blanc, bordure fine, coin arrondi — remplace le style
/// "réglages iOS" par défaut des List/Form.
struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

/// Couleur distincte par groupe musculaire, pour identifier un exercice au premier coup d'œil.
enum MuscleGroupStyle {
    static let order = ["Épaules", "Pectoraux", "Triceps", "Dos", "Biceps", "Jambes", "Abdos"]

    static func color(for group: String) -> Color {
        switch group {
        case "Épaules": return .orange
        case "Pectoraux": return .pink
        case "Triceps": return .purple
        case "Dos": return .blue
        case "Biceps": return .indigo
        case "Jambes": return .green
        case "Abdos": return .brown
        default: return .gray
        }
    }
}

/// Tag coloré pour un groupe musculaire (fond teinté + texte de la même teinte, comme le reste du thème).
struct MuscleGroupTag: View {
    let group: String

    var body: some View {
        let color = MuscleGroupStyle.color(for: group)
        Text(group)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Tuile chiffre : libellé discret + grande valeur + cible optionnelle, façon "Masse grasse 20,0% → 15,0%".
struct StatTile: View {
    let label: String
    let value: String
    var target: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTheme.Font.statLabel)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(AppTheme.Font.statValue)
                    .foregroundStyle(AppTheme.textPrimary)
                if let target {
                    Text("→ \(target)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(AppTheme.Font.sectionHeader)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 4)
    }
}

/// Applique les couleurs de fond de liste/nav/tab bar du thème sur toute l'app.
enum AppAppearance {
    static func apply() {
        let bg = UIColor(AppTheme.background)
        let surface = UIColor(AppTheme.surface)
        let accent = UIColor(AppTheme.accent)

        UITableView.appearance().backgroundColor = bg
        UICollectionView.appearance().backgroundColor = bg

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = bg
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.textPrimary)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppTheme.textPrimary)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accent

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = surface
        tabAppearance.shadowColor = UIColor(AppTheme.border)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = accent
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppTheme.textSecondary)
    }
}
