import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Import d'un programme reçu de Claude (même format JSON que la restauration de sauvegarde) —
/// pensé pour le flux "on définit le programme ensemble en conversation, je récupère un fichier,
/// je l'importe en un clic" plutôt que de tout construire à la main dans l'app.
struct ProgramImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingPicker = false
    @State private var result: BilanRestoreImporter.RestoreResult?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Importe un programme préparé avec Claude en conversation, sous forme de fichier JSON.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)

                    Button {
                        isShowingPicker = true
                    } label: {
                        AppCard {
                            HStack {
                                Text("Choisir un fichier de programme")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AppTheme.accent)
                                Spacer()
                                Image(systemName: "arrow.down.doc")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 13)).foregroundStyle(.red)
                    }

                    if let result {
                        AppCard {
                            VStack(alignment: .leading, spacing: 10) {
                                summaryRow(label: "Programmes importés", value: result.restoredPrograms)
                                summaryRow(label: "Cycles importés", value: result.restoredCycles)
                                summaryRow(label: "Séances importées", value: result.restoredSessions)
                            }
                        }
                        Button {
                            dismiss()
                        } label: {
                            Text("Terminé")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Importer un programme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .fileImporter(isPresented: $isShowingPicker, allowedContentTypes: [.json]) { pickerResult in
                switch pickerResult {
                case .success(let url):
                    do {
                        result = try BilanRestoreImporter.restore(url: url, context: context)
                        errorMessage = nil
                    } catch {
                        errorMessage = "Impossible de lire ce fichier de programme."
                        result = nil
                    }
                case .failure:
                    errorMessage = "Sélection du fichier annulée ou impossible."
                }
            }
        }
    }

    private func summaryRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}
