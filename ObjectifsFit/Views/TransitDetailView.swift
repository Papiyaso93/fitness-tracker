import SwiftUI
import SwiftData

struct TransitDetailView: View {
    @Bindable var log: TransitLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                DatePicker("Heure", selection: $log.dateTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            } header: { formSectionHeader("Heure", required: true) }
            Section {
                BristolScaleField(selection: $log.bristolType)
            } header: { formSectionHeader("Échelle de Bristol", required: true) }
            Section {
                Button("Supprimer ce passage", role: .destructive) {
                    context.delete(log)
                    dismiss()
                }
            }
        }
        .navigationTitle("Passage")
        .navigationBarTitleDisplayMode(.inline)
    }
}
