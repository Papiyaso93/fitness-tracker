import SwiftUI
import SwiftData

/// Ajout d'une mesure (poids, tour de taille, VO2max, mensurations...) — date d'abord puis type
/// puis valeur, même ordre que les autres formulaires de saisie de l'app.
struct AddBodyMeasurementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Calendar.current.startOfDay(for: .now)
    @State private var type: ObjectiveMetricType = .poids
    @State private var valueText = ""

    private var canSave: Bool {
        Double(valueText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(selection: $date, in: ...Date.now, displayedComponents: .date) {
                        fieldLabel("Date")
                    }
                } header: { formSectionHeader("Date") }

                Section {
                    AppMenuField(
                        label: "Type de mesure",
                        options: ObjectiveMetricType.allCases.filter { $0 != .autre && $0 != .nombreDePas }.map { ($0, $0.rawValue) },
                        selection: $type,
                        required: true,
                        showsLabel: false
                    )
                } header: { formSectionHeader("Type de mesure", required: true) }

                Section {
                    LabeledContent {
                        TextField("0", text: $valueText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        fieldLabel("Valeur\(unitSuffix)", required: true)
                    }
                } header: { formSectionHeader("Valeur", required: true) }
            }
            .navigationTitle("Nouvelle mesure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var unitSuffix: String {
        type.unit.isEmpty ? "" : " (\(type.unit))"
    }

    private func save() {
        guard let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) else { return }
        context.insert(BodyMeasurementEntry(type: type, value: value, date: date))
        dismiss()
    }
}
