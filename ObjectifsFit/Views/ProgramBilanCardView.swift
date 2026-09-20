import SwiftUI
import SwiftData

/// Équivalent de `CycleBilanCardView` pour un programme — visible dans les 7 jours avant sa date
/// de fin ou après (pas de notion de semaine comme pour un cycle), même logique d'état "fait"
/// une fois un bilan importé et lié à ce programme précis.
struct ProgramBilanCardView: View {
    @Bindable var program: TrainingProgram

    @Query private var linkedBilans: [ArchivedBilan]
    @Environment(\.modelContext) private var context

    @State private var shareItems: [Any]?
    @State private var showsImporter = false
    @State private var selectedBilan: ArchivedBilan?
    @State private var actionError: String?

    init(program: TrainingProgram) {
        self.program = program
        let programId = program.id
        _linkedBilans = Query(filter: #Predicate<ArchivedBilan> { $0.linkedProgramId == programId })
    }

    private var isOver: Bool {
        guard let endDate = program.endDate else { return false }
        return Date.now >= endDate
    }

    private var isNearEndOrOver: Bool {
        guard let endDate = program.endDate else { return false }
        return Date.now >= endDate.addingTimeInterval(-7 * 86400)
    }

    private var objectivesSummary: String {
        let summaries = program.principalObjectives.map(\.summary).filter { !$0.isEmpty }
        return summaries.isEmpty ? "aucun objectif principal défini" : summaries.joined(separator: " ; ")
    }

    var body: some View {
        Group {
            if let bilan = linkedBilans.first {
                doneRow(bilan)
            } else if isNearEndOrOver {
                actionCard
            }
        }
        .sheet(item: $selectedBilan) { bilan in
            BilanPDFDetailView(bilan: bilan)
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            if let shareItems {
                ShareSheet(activityItems: shareItems)
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.pdf]) { result in
            handleImport(result)
        }
        .alert("Action impossible", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    private func doneRow(_ bilan: ArchivedBilan) -> some View {
        AppCard {
            Button {
                selectedBilan = bilan
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(AppTheme.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bilan réalisé")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Importé le \(bilan.importedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "B4AFA6"))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var actionCard: some View {
        AppCard {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text("Bilan de programme")
                    .font(AppTheme.Font.cardTitle)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text(isOver
                 ? "Ce programme est terminé — transmets-le à un coach sportif pour un bilan et une proposition pour la suite."
                 : "Ce programme se termine bientôt — transmets-le à un coach sportif pour un bilan et une proposition pour la suite.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let requestedAt = program.lastAnalysisRequestedAt {
                Text("Analysé le \(requestedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondary)
            }

            Button {
                exportAndShare()
            } label: {
                Label("Analyser ce programme", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)

            Button {
                showsImporter = true
            } label: {
                Label("Importer le bilan du programme", systemImage: "square.and.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(AppTheme.textPrimary)
                    .background(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border, lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
        }
    }

    private func exportAndShare() {
        do {
            let payload = try BilanExportBuilder.build(context: context)
            let data = try BilanExportBuilder.encodeJSON(payload)
            let dateStamp = payload.exportedAt.formatted(.iso8601.year().month().day())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("bilan_programme_\(dateStamp).json")
            try data.write(to: url, options: .atomic)
            let prompt = BilanPrompt.programEnd(
                programTitle: program.title,
                startDate: program.startDate,
                endDate: program.endDate,
                objectivesSummary: objectivesSummary
            )
            program.lastAnalysisRequestedAt = .now
            shareItems = [prompt, url]
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            actionError = error.localizedDescription
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                actionError = "Impossible d'accéder au fichier sélectionné."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let title = "Bilan du \(Date.now.formatted(date: .abbreviated, time: .omitted))"
                let bilan = ArchivedBilan(title: title, pdfData: data, linkedProgramId: program.id, linkLabel: program.title)
                context.insert(bilan)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}
