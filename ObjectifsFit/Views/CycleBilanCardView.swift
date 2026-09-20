import SwiftUI
import SwiftData

/// Carte "Bilan de cycle" sur la page de détail d'un cycle — visible en dernière semaine du cycle
/// ou après sa fin (pas seulement une fois "Terminé", pour permettre un envoi la veille si la
/// dernière séance n'a pas lieu). Bascule vers un état "fait" une fois un bilan importé et lié à
/// ce cycle précis, qui remplace alors le bloc d'action.
struct CycleBilanCardView: View {
    @Bindable var cycle: Cycle

    @Query private var linkedBilans: [ArchivedBilan]
    @Environment(\.modelContext) private var context

    @State private var shareItems: [Any]?
    @State private var showsImporter = false
    @State private var selectedBilan: ArchivedBilan?
    @State private var actionError: String?

    init(cycle: Cycle) {
        self.cycle = cycle
        let cycleId = cycle.id
        _linkedBilans = Query(filter: #Predicate<ArchivedBilan> { $0.linkedCycleId == cycleId })
    }

    private var isOver: Bool {
        Date.now >= cycle.endDate
    }

    private var isNearEndOrOver: Bool {
        isOver || cycle.weekNumber(for: .now) >= cycle.weekCount
    }

    private var objectivesSummary: String {
        var parts: [String] = []
        if !cycle.objectifsPrincipaux.isEmpty {
            parts.append("qualités visées : " + cycle.objectifsPrincipaux.map(\.rawValue).joined(separator: ", "))
        }
        parts.append(contentsOf: cycle.sortedObjectives.map(\.summary).filter { !$0.isEmpty })
        return parts.isEmpty ? "aucun objectif chiffré défini" : parts.joined(separator: " ; ")
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
                Text("Bilan de cycle")
                    .font(AppTheme.Font.cardTitle)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text(isOver
                 ? "Ce cycle est terminé — transmets-le à un coach sportif pour un bilan et une proposition pour la suite."
                 : "Ce cycle se termine bientôt — transmets-le à un coach sportif pour un bilan et une proposition pour la suite.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let requestedAt = cycle.lastAnalysisRequestedAt {
                Text("Analysé le \(requestedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondary)
            }

            Button {
                exportAndShare()
            } label: {
                Label("Analyser ce cycle", systemImage: "square.and.arrow.up")
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
                Label("Importer le bilan du cycle", systemImage: "square.and.arrow.down")
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
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("bilan_cycle_\(dateStamp).json")
            try data.write(to: url, options: .atomic)
            let prompt = BilanPrompt.cycleEnd(
                cycleName: cycle.name,
                startDate: cycle.startDate,
                endDate: cycle.endDate,
                objectivesSummary: objectivesSummary
            )
            cycle.lastAnalysisRequestedAt = .now
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
                let bilan = ArchivedBilan(title: title, pdfData: data, linkedCycleId: cycle.id, linkLabel: cycle.name)
                context.insert(bilan)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}
