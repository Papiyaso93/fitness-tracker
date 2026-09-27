import SwiftUI
import SwiftData

private enum WeeklyModule: CaseIterable {
    case forme, course, steps, note

    var label: String {
        switch self {
        case .forme: return "Niveau de forme"
        case .course: return "Volume de course (km)"
        case .steps: return "Nombre de pas moyen/jour"
        case .note: return "Note libre"
        }
    }
}

extension WeeklyFormLevel {
    /// Mêmes 3 palettes (teal/ambre/corail) que `MealSensation`/`BristolType` — cohérent avec le
    /// reste de l'app plutôt que d'inventer une nouvelle échelle de couleurs.
    var categoryColor: (background: Color, selected: Color, text: Color) {
        switch self {
        case .bien: return (Color(hex: "E1F5EE"), AppTheme.secondary, Color(hex: "0F6E56"))
        case .fatigue: return (Color(hex: "FAEEDA"), Color(hex: "BA7517"), Color(hex: "854F0B"))
        case .dur: return (Color(hex: "FAECE7"), Color(hex: "D85A30"), Color(hex: "993C1D"))
        }
    }
}

struct WeeklyFormLevelField: View {
    @Binding var selection: WeeklyFormLevel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WeeklyFormLevel.allCases, id: \.self) { level in
                Button {
                    selection = level
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: level.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(level.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .foregroundStyle(selection == level ? .white : level.categoryColor.text)
                    .background(selection == level ? level.categoryColor.selected : level.categoryColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        if selection == level {
                            RoundedRectangle(cornerRadius: 10).stroke(AppTheme.accent, lineWidth: 2.5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Saisie du bilan hebdomadaire — un premier écran pour choisir les modules à remplir cette
/// semaine (tout n'a pas besoin d'être renseigné à chaque fois), puis un écran par module
/// sélectionné, dans l'ordre `WeeklyModule.allCases`.
struct WeeklyCheckInEntryView: View {
    let weekDate: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Modules proposés au choix dans le premier écran — la note libre n'en fait pas partie : elle
    /// est systématiquement demandée en dernière étape, sans avoir besoin d'être cochée.
    private static let pickableModules = WeeklyModule.allCases.filter { $0 != .note }

    @State private var selectedModules: Set<WeeklyModule> = [.forme, .course]
    /// 0 = choix des modules, 1...N = étape du n-ième module sélectionné.
    @State private var step = 0
    @State private var formLevel: WeeklyFormLevel = .bien
    @State private var formComment = ""
    @State private var runningVolumeText = ""
    @State private var stepsText = ""
    @State private var note = ""

    private var orderedModules: [WeeklyModule] {
        Self.pickableModules.filter { selectedModules.contains($0) } + [.note]
    }

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 {
                    modulePicker
                } else {
                    moduleStep(orderedModules[step - 1])
                }
            }
            .navigationTitle("Bilan hebdomadaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private var modulePicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Qu'est-ce que tu veux renseigner cette semaine ?")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)

                AppCard {
                    VStack(spacing: 0) {
                        ForEach(Array(Self.pickableModules.enumerated()), id: \.offset) { index, module in
                            if index > 0 { Divider().overlay(AppTheme.border) }
                            moduleToggleRow(module)
                        }
                    }
                }

                Button {
                    step = 1
                } label: {
                    Text("Continuer").primaryButtonStyle()
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(AppTheme.background)
    }

    private func moduleToggleRow(_ module: WeeklyModule) -> some View {
        let isSelected = selectedModules.contains(module)
        return Button {
            if isSelected { selectedModules.remove(module) } else { selectedModules.insert(module) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? AppTheme.accent : Color(hex: "D8D4C8"))
                Text(module.label)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func moduleStep(_ module: WeeklyModule) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("\(step) / \(orderedModules.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                switch module {
                case .forme:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comment tu te sens cette semaine ?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        WeeklyFormLevelField(selection: $formLevel)
                        TextField("Pourquoi ? (optionnel)", text: $formComment, axis: .vertical)
                            .padding(12)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                case .course:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Combien de km as-tu couru cette semaine ?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        HStack {
                            TextField("0", text: $runningVolumeText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 20, weight: .semibold))
                            Text("km")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(12)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                case .steps:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quelle a été ta moyenne quotidienne de pas cette semaine ?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        HStack {
                            TextField("0", text: $stepsText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 20, weight: .semibold))
                            Text("pas/jour")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(12)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                case .note:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Autre chose à noter sur ta semaine ?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        TextField("Ex: cheville encore sensible après jambes", text: $note, axis: .vertical)
                            .padding(12)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button {
                    advance()
                } label: {
                    Text(step == orderedModules.count ? "Terminer" : "Suivant")
                        .primaryButtonStyle()
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(AppTheme.background)
    }

    private func advance() {
        if step < orderedModules.count {
            step += 1
        } else {
            save()
        }
    }

    private func save() {
        let checkIn = WeeklyCheckIn(weekDate: weekDate)
        if selectedModules.contains(.forme) {
            checkIn.formLevel = formLevel
            let trimmedComment = formComment.trimmingCharacters(in: .whitespacesAndNewlines)
            checkIn.formComment = trimmedComment.isEmpty ? nil : trimmedComment
        }
        if selectedModules.contains(.course) {
            checkIn.runningVolumeKm = Double(runningVolumeText.replacingOccurrences(of: ",", with: "."))
        }
        if selectedModules.contains(.steps) {
            checkIn.averageStepsPerDay = Int(stepsText)
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        checkIn.note = trimmedNote.isEmpty ? nil : trimmedNote
        context.insert(checkIn)
        dismiss()
    }
}
