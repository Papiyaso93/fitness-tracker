import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Import ponctuel d'un historique de séries (export CSV) directement en `PlannedSetEntry` — utile
/// pour ne pas repartir d'une app vide après une réinstallation ou sur un nouvel appareil.
struct ImportHistoryView: View {
    @Environment(\.modelContext) private var context

    @State private var isShowingFilePicker = false
    @State private var result: HistoryCSVImporter.ImportResult?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Importe un fichier CSV de séries (colonnes Date, Groupe musculaire, Exercice, Mode de résistance, Poids, Répétitions, Sensation...). Les séries sont ajoutées directement à ton historique et alimentent le Tableau de bord, sans créer de séance ni de programme.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)

                Button {
                    isShowingFilePicker = true
                } label: {
                    AppCard {
                        HStack {
                            Text("Choisir un fichier CSV")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.accent)
                            Spacer()
                            Image(systemName: "doc.badge.plus")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .buttonStyle(.plain)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }

                if let result {
                    AppCard {
                        VStack(alignment: .leading, spacing: 10) {
                            importSummaryRow(label: "Séries importées", value: "\(result.importedCount)")
                            if result.duplicateCount > 0 {
                                importSummaryRow(label: "Déjà présentes (ignorées)", value: "\(result.duplicateCount)")
                            }
                            if result.skippedCount > 0 {
                                importSummaryRow(label: "Lignes ignorées", value: "\(result.skippedCount)")
                            }
                            if !result.unmatchedExerciseNames.isEmpty {
                                Divider()
                                Text("Exercices non reconnus (non importés) :")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(result.unmatchedExerciseNames.sorted().joined(separator: ", "))
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Importer mon historique")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $isShowingFilePicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { pickerResult in
            switch pickerResult {
            case .success(let url):
                do {
                    result = try HistoryCSVImporter.importCSV(url: url, context: context)
                    errorMessage = nil
                } catch {
                    errorMessage = "Impossible de lire ce fichier CSV."
                    result = nil
                }
            case .failure:
                errorMessage = "Sélection du fichier annulée ou impossible."
            }
        }
    }

    private func importSummaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}
