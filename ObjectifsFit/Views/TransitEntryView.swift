import SwiftUI
import SwiftData

extension BristolType {
    var categoryColor: (background: Color, selected: Color, text: Color) {
        switch category {
        case "Constipation": return (Color(hex: "FAEEDA"), Color(hex: "BA7517"), Color(hex: "854F0B"))
        case "Normal": return (Color(hex: "E1F5EE"), AppTheme.secondary, Color(hex: "0F6E56"))
        default: return (Color(hex: "FAECE7"), Color(hex: "D85A30"), Color(hex: "993C1D"))
        }
    }
}

/// Sélecteur d'échelle de Bristol réutilisable (création et édition d'un passage) : bandeau de 7
/// cases colorées par catégorie + détail du type sélectionné, avec anneau accent sur la case active.
struct BristolScaleField: View {
    @Binding var selection: BristolType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(BristolType.allCases) { type in
                    Button {
                        selection = type
                    } label: {
                        Text("\(type.rawValue)")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .foregroundStyle(selection == type ? .white : type.categoryColor.text)
                            .background(selection == type ? type.categoryColor.selected : type.categoryColor.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                if selection == type {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppTheme.accent, lineWidth: 2.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(selection.shortLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selection.categoryColor.text)
                Text(selection.category)
                    .font(.system(size: 12))
                    .foregroundStyle(selection.categoryColor.text)
            }
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

struct TransitEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var dateTime = Date.now
    @State private var bristolType: BristolType = .type4

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Heure", selection: $dateTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                } header: { formSectionHeader("Heure", required: true) }
                Section {
                    BristolScaleField(selection: $bristolType)
                } header: { formSectionHeader("Échelle de Bristol", required: true) }
            }
            .navigationTitle("Nouveau passage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let log = TransitLog(dateTime: dateTime, bristolType: bristolType)
                        context.insert(log)
                        dismiss()
                    }
                }
            }
        }
    }
}
