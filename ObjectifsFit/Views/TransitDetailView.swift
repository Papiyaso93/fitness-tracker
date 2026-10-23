import SwiftUI
import SwiftData

struct TransitDetailView: View {
    @Bindable var log: TransitLog

    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                DatePicker("Heure", selection: $log.dateTime, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            } header: { formSectionHeader("Heure", required: true) }
            Section {
                BristolScaleField(selection: $log.bristolType)
            } header: { formSectionHeader("Échelle de Bristol", required: true) }
            Section {
                Button("Supprimer ce passage", role: .destructive) {
                    context.delete(log)
                    toast.showDeleted("Passage supprimé", context: context)
                    dismiss()
                }
            }
        }
        .navigationTitle("Passage")
        .navigationBarTitleDisplayMode(.inline)
    }
}
