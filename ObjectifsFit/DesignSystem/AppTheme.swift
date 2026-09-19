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

/// Champ de sélection en menu natif, réutilisable — remplace le style natif orange (chevron
/// haut/bas) par un texte neutre + chevron bas, comme "Objectif de la séance". Deux inits :
/// sélection facultative (placeholder gris tant que rien n'est choisi) ou obligatoire (toujours
/// une valeur affichée, ex: Sensation, Mode de résistance).
struct AppMenuField<Value: Hashable>: View {
    let label: String
    let placeholder: String
    let options: [(value: Value, label: String)]
    @Binding var selection: Value?
    var disabled: Bool = false
    var required: Bool = false
    /// À false, n'affiche que la valeur/placeholder + chevron, sans répéter le nom du champ — pour
    /// les champs seuls dans leur Section (le header de Section fait déjà office de label), comme
    /// "Objectif de la séance". Garder à true quand plusieurs champs partagent une même Section
    /// (ambiguïté sinon, y compris en VoiceOver).
    var showsLabel: Bool = true

    init(label: String, placeholder: String = "Choisir…", options: [(Value, String)], selection: Binding<Value?>, disabled: Bool = false, required: Bool = false, showsLabel: Bool = true) {
        self.label = label
        self.placeholder = placeholder
        self.options = options
        self._selection = selection
        self.disabled = disabled
        self.required = required
        self.showsLabel = showsLabel
    }

    init(label: String, options: [(Value, String)], selection: Binding<Value>, disabled: Bool = false, required: Bool = false, showsLabel: Bool = true) {
        self.label = label
        self.placeholder = ""
        self.options = options
        self._selection = Binding(
            get: { selection.wrappedValue },
            set: { if let newValue = $0 { selection.wrappedValue = newValue } }
        )
        self.disabled = disabled
        self.required = required
        self.showsLabel = showsLabel
    }

    private var currentLabel: String? {
        guard let selection else { return nil }
        return options.first { $0.value == selection }?.label
    }

    var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    if selection == option.value {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack {
                if showsLabel {
                    Group {
                        if required {
                            Text(label) + Text(" *").foregroundStyle(AppTheme.accent)
                        } else {
                            Text(label)
                        }
                    }
                    .foregroundStyle(disabled ? AppTheme.textSecondary.opacity(0.5) : AppTheme.textPrimary)
                    Spacer()
                }
                Text(currentLabel ?? placeholder)
                    .foregroundStyle(currentLabel == nil ? Color(hex: "B4AFA6") : AppTheme.textPrimary)
                if !showsLabel {
                    Spacer()
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(disabled ? 0.5 : 1))
            }
            .contentShape(Rectangle())
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

/// Segmented control réutilisable aux couleurs de l'app (pilule orange pleine sur la sélection)
/// — remplace le `Picker(.segmented)` natif gris partout où un choix à 2-3 options apparaît dans
/// un formulaire, pour un rendu identique sur tout l'app plutôt qu'un mix natif/custom.
struct AppSegmentedControl<Item: Hashable>: View {
    let options: [(value: Item, label: String)]
    @Binding var selection: Item

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selection == option.value ? .white : AppTheme.textSecondary)
                        .background(selection == option.value ? AppTheme.accent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Couleur commune à tous les labels de formulaire (headers de Section, légendes au-dessus des
/// champs, labels de Picker/LabeledContent) — un seul gris plus foncé que le gris système par
/// défaut, pour rester lisible sur le fond crème, et surtout identique que le champ soit
/// obligatoire ou non (seul l'astérisque change).
private let formLabelColor = Color(hex: "4A4038")

/// Header de `Section` standard — remplace `Section("X")` pour garantir la même couleur/poids
/// sur tous les formulaires plutôt que de dépendre du style natif (qui variait). `required`
/// ajoute un astérisque orange après le texte.
func formSectionHeader(_ text: String, required: Bool = false) -> some View {
    Group {
        if required {
            Text(text) + Text(" *").foregroundStyle(AppTheme.accent)
        } else {
            Text(text)
        }
    }
    .font(.system(size: 12, weight: .semibold))
    .foregroundStyle(formLabelColor)
    .textCase(.uppercase)
}

/// Label de `Picker`/`LabeledContent` (texte normal, pas de transformation) avec astérisque
/// orange optionnel.
func fieldLabel(_ text: String, required: Bool = false) -> Text {
    required ? Text(text) + Text(" *").foregroundStyle(AppTheme.accent) : Text(text)
}

/// Légende (13pt) au-dessus d'un `TextField`, même couleur que les headers de Section, avec
/// astérisque orange optionnel.
func fieldCaption(_ text: String, required: Bool = false) -> some View {
    Group {
        if required {
            Text(text) + Text(" *").foregroundStyle(AppTheme.accent)
        } else {
            Text(text)
        }
    }
    .font(.system(size: 13))
    .foregroundStyle(formLabelColor)
}

/// Design system "Genki" — fond blanc cassé neutre, cartes blanches, accent orange (repris du
/// logo) + secondaire vert profond pour les statuts positifs. Mode sombre à construire plus
/// tard (cf. décision produit).
enum AppTheme {
    static let background = Color(hex: "FAFAF8")
    static let surface = Color.white
    static let border = Color(hex: "E7E4DC")
    static let accent = Color(hex: "E8703A")
    static let secondary = Color(hex: "2B6E63")
    static let textPrimary = Color(hex: "2A2521")
    static let textSecondary = Color(hex: "8A7A6C")

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
    static let order = ["Abdos", "Biceps", "Dos", "Épaules", "Jambes", "Pectoraux", "Triceps"]

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

/// Enchaîne des vues (typiquement des badges) avec retour à la ligne automatique — pour les listes
/// de tags de longueur variable (qualités d'un cycle, etc.) où un `HStack` déborderait.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + spacing
                currentRowWidth = 0
                currentRowHeight = 0
            }
            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += currentRowHeight + spacing
                currentRowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
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
            .tracking(0.6)
            .foregroundStyle(Color(hex: "6B5D50"))
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
        UITableView.appearance().separatorColor = UIColor(AppTheme.border)
        UITableViewCell.appearance().backgroundColor = surface

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
