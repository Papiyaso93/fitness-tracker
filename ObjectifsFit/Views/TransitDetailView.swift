import SwiftUI
import SwiftData

struct TransitDetailView: View {
    @Bindable var log: TransitLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Heure") {
                DatePicker("Heure", selection: $log.dateTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            Section("Échelle de Bristol") {
                ForEach(BristolType.allCases) { type in
                    Button {
                        log.bristolType = type
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
                            if log.bristolType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }
            }
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
