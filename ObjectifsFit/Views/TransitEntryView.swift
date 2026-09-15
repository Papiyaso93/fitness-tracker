import SwiftUI
import SwiftData

struct TransitEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var dateTime = Date.now
    @State private var bristolType: BristolType = .type4

    var body: some View {
        NavigationStack {
            Form {
                Section("Heure") {
                    DatePicker("Heure", selection: $dateTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                Section("Échelle de Bristol") {
                    ForEach(BristolType.allCases) { type in
                        Button {
                            bristolType = type
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.shortLabel)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(type.category)
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                if bristolType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                    }
                }
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
