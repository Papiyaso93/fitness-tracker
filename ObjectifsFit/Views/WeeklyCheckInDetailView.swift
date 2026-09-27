import SwiftUI
import SwiftData

/// Édition d'un bilan hebdomadaire déjà rempli — contrairement à la saisie initiale (par étapes,
/// modules choisis un par un), ici tout est modifiable directement, y compris un module qui
/// n'avait pas été renseigné au départ.
struct WeeklyCheckInDetailView: View {
    @Bindable var checkIn: WeeklyCheckIn

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var runningVolumeText: String
    @State private var noteText: String

    init(checkIn: WeeklyCheckIn) {
        self.checkIn = checkIn
        _runningVolumeText = State(initialValue: checkIn.runningVolumeKm.map { $0.formatted() } ?? "")
        _noteText = State(initialValue: checkIn.note ?? "")
    }

    private var formLevelBinding: Binding<WeeklyFormLevel> {
        Binding(get: { checkIn.formLevel ?? .bien }, set: { checkIn.formLevel = $0 })
    }

    var body: some View {
        Form {
            Section {
                WeeklyFormLevelField(selection: formLevelBinding)
                    .listRowInsets(EdgeInsets())
                    .padding(4)
            } header: { formSectionHeader("Niveau de forme") }

            Section {
                HStack {
                    TextField("0", text: $runningVolumeText)
                        .keyboardType(.decimalPad)
                        .onChange(of: runningVolumeText) { _, newValue in
                            checkIn.runningVolumeKm = Double(newValue.replacingOccurrences(of: ",", with: "."))
                        }
                    Text("km").foregroundStyle(AppTheme.textSecondary)
                }
            } header: { formSectionHeader("Volume de course") }

            Section {
                TextField("Note libre", text: $noteText, axis: .vertical)
                    .onChange(of: noteText) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        checkIn.note = trimmed.isEmpty ? nil : newValue
                    }
            } header: { formSectionHeader("Note libre") }

            Section {
                Button("Supprimer ce bilan", role: .destructive) {
                    context.delete(checkIn)
                    dismiss()
                }
            }
        }
        .navigationTitle("Bilan du \(AppDateFormat.dayFullMonth.string(from: checkIn.weekDate))")
        .navigationBarTitleDisplayMode(.inline)
    }
}
