import SwiftUI
import SwiftData

extension MealSensation {
    var categoryColor: (background: Color, selected: Color, text: Color) {
        switch self {
        case .encoreFaim, .tropMange: return (Color(hex: "FAEEDA"), Color(hex: "BA7517"), Color(hex: "854F0B"))
        case .rassasie80: return (Color(hex: "E1F5EE"), AppTheme.secondary, Color(hex: "0F6E56"))
        case .rassasiePile: return (Color(hex: "E1F5EE"), Color(hex: "5DCAA5"), Color(hex: "0F6E56"))
        case .ballonneInconfortable: return (Color(hex: "FAECE7"), Color(hex: "D85A30"), Color(hex: "993C1D"))
        }
    }
}

/// Sélecteur de sensation réutilisable (création et édition d'un repas) : bandeau de 5 cases
/// (icône + couleur par catégorie) + détail de la sensation sélectionnée, cible mise en avant.
struct MealSensationField: View {
    @Binding var selection: MealSensation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(MealSensation.allCases, id: \.self) { level in
                    Button {
                        selection = level
                    } label: {
                        Image(systemName: level.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(selection == level ? .white : level.categoryColor.text)
                            .background(selection == level ? level.categoryColor.selected : level.categoryColor.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                if selection == level {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppTheme.accent, lineWidth: 2.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(selection.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selection.categoryColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            .background(selection.categoryColor.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }
}

struct MealEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var dateTime = Date.now
    @State private var title = ""
    @State private var description = ""
    @State private var sensation: MealSensation = .rassasie80

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Heure", selection: $dateTime, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                } header: { formSectionHeader("Heure", required: true) }
                Section {
                    TextField("Ex: Déjeuner, Dîner, Collation", text: $title)
                } header: { formSectionHeader("Titre", required: true) }
                Section {
                    TextField("Qu'as-tu mangé ?", text: $description, axis: .vertical)
                } header: { formSectionHeader("Description") }
                Section {
                    MealSensationField(selection: $sensation)
                } header: { formSectionHeader("Sensation", required: true) }
            }
            .navigationTitle("Nouveau repas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let meal = MealLog(dateTime: dateTime, title: title, mealDescription: description, sensation: sensation)
                        context.insert(meal)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
