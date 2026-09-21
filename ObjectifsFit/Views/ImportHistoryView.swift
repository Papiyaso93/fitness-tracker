import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Deux imports distincts pour deux besoins distincts :
/// - CSV : migration ponctuelle depuis un historique externe (ex: export Notion), directement en
///   `PlannedSetEntry` sans créer de fausses séances.
/// - JSON : restauration d'une sauvegarde complète produite par "Analyser mes données" (carte
///   Bilan coach), pour récupérer tout son historique sur un nouvel appareil.
/// Les deux sont idempotents : réimporter le même fichier ne duplique rien.
struct ImportHistoryView: View {
    @Environment(\.modelContext) private var context

    @State private var isShowingCSVPicker = false
    @State private var csvResult: HistoryCSVImporter.ImportResult?
    @State private var csvError: String?

    @State private var isShowingJSONPicker = false
    @State private var restoreResult: BilanRestoreImporter.RestoreResult?
    @State private var restoreError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                csvSection
                restoreSection
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Données")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var csvSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Importer un historique CSV")
            Text("Ajoute tes séries passées depuis un fichier CSV externe. À utiliser une seule fois.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                isShowingCSVPicker = true
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

            if let csvError {
                Text(csvError).font(.system(size: 13)).foregroundStyle(.red)
            }

            if let csvResult {
                AppCard {
                    VStack(alignment: .leading, spacing: 10) {
                        importSummaryRow(label: "Séries importées", value: "\(csvResult.importedCount)")
                        if csvResult.duplicateCount > 0 {
                            importSummaryRow(label: "Déjà présentes (ignorées)", value: "\(csvResult.duplicateCount)")
                        }
                        if csvResult.skippedCount > 0 {
                            importSummaryRow(label: "Lignes ignorées", value: "\(csvResult.skippedCount)")
                        }
                        if !csvResult.unmatchedExerciseNames.isEmpty {
                            Divider()
                            Text("Exercices non reconnus (non importés) :")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(csvResult.unmatchedExerciseNames.sorted().joined(separator: ", "))
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $isShowingCSVPicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { pickerResult in
            switch pickerResult {
            case .success(let url):
                do {
                    csvResult = try HistoryCSVImporter.importCSV(url: url, context: context)
                    csvError = nil
                } catch {
                    csvError = "Impossible de lire ce fichier CSV."
                    csvResult = nil
                }
            case .failure:
                csvError = "Sélection du fichier annulée ou impossible."
            }
        }
    }

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Restaurer une sauvegarde")
            Text("Réimporte une sauvegarde JSON pour récupérer tes données sur un nouvel appareil.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                isShowingJSONPicker = true
            } label: {
                AppCard {
                    HStack {
                        Text("Choisir un fichier de sauvegarde")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                        Spacer()
                        Image(systemName: "arrow.down.doc")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .buttonStyle(.plain)

            if let restoreError {
                Text(restoreError).font(.system(size: 13)).foregroundStyle(.red)
            }

            if let restoreResult {
                AppCard {
                    VStack(alignment: .leading, spacing: 10) {
                        importSummaryRow(label: "Programmes restaurés", value: "\(restoreResult.restoredPrograms)")
                        importSummaryRow(label: "Cycles restaurés", value: "\(restoreResult.restoredCycles)")
                        importSummaryRow(label: "Séances restaurées", value: "\(restoreResult.restoredSessions)")
                        importSummaryRow(label: "Séries restaurées", value: "\(restoreResult.restoredSetEntries)")
                        importSummaryRow(label: "Repas restaurés", value: "\(restoreResult.restoredMeals)")
                        importSummaryRow(label: "Transit restauré", value: "\(restoreResult.restoredTransitLogs)")
                        importSummaryRow(label: "Sommeil restauré", value: "\(restoreResult.restoredSleepLogs)")
                        importSummaryRow(label: "Mesures restaurées", value: "\(restoreResult.restoredMetricEntries)")
                        if restoreResult.skippedExisting > 0 {
                            importSummaryRow(label: "Déjà présents (ignorés)", value: "\(restoreResult.skippedExisting)")
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $isShowingJSONPicker, allowedContentTypes: [.json]) { pickerResult in
            switch pickerResult {
            case .success(let url):
                do {
                    restoreResult = try BilanRestoreImporter.restore(url: url, context: context)
                    restoreError = nil
                } catch {
                    restoreError = "Impossible de lire ce fichier de sauvegarde."
                    restoreResult = nil
                }
            case .failure:
                restoreError = "Sélection du fichier annulée ou impossible."
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
