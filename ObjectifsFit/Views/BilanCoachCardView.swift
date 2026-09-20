import SwiftUI
import SwiftData

/// Carte "Bilan coach" en haut du Tableau de bord : export JSON + prompt à transmettre à Claude,
/// import de bilans PDF reçus en retour, et liste des bilans déjà archivés — conception validée
/// le 2026-09-20 (voir mémoire projet `project_objectifsfit_data_export`).
struct BilanCoachCardView: View {
    @Query(sort: \ArchivedBilan.importedAt, order: .reverse) private var bilans: [ArchivedBilan]

    @Environment(\.modelContext) private var context

    @State private var shareItems: [Any]?
    @State private var showsImporter = false
    @State private var showsAllBilans = false
    @State private var selectedBilan: ArchivedBilan?
    @State private var exportError: String?

    private let collapsedCount = 2

    private var visibleBilans: [ArchivedBilan] {
        showsAllBilans ? bilans : Array(bilans.prefix(collapsedCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            coachCard
            if !bilans.isEmpty {
                bilansSection
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
        .alert("Export impossible", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private var coachCard: some View {
        AppCard {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text("Bilan coach")
                    .font(AppTheme.Font.cardTitle)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text("Exporte tes données et transmets-les à un coach sportif pour une analyse complète.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                exportAndShare()
            } label: {
                Label("Analyser mes données", systemImage: "square.and.arrow.up")
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
                Label("Importer un bilan", systemImage: "square.and.arrow.down")
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

    private var bilansSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                SectionLabel(text: "Bilans")
                Text("(\(bilans.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            AppCard {
                VStack(spacing: 0) {
                    ForEach(Array(visibleBilans.enumerated()), id: \.element.id) { index, bilan in
                        if index > 0 { Divider().overlay(AppTheme.border) }
                        Button {
                            selectedBilan = bilan
                        } label: {
                            bilanRow(bilan)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if bilans.count > collapsedCount {
                    Button {
                        withAnimation { showsAllBilans.toggle() }
                    } label: {
                        Text(showsAllBilans ? "Voir moins" : "Voir plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func bilanRow(_ bilan: ArchivedBilan) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bilan.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    if let linkLabel = bilan.linkLabel {
                        Text(linkLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(AppTheme.secondary.opacity(0.15))
                            .foregroundStyle(AppTheme.secondary)
                            .clipShape(Capsule())
                    }
                }
                Text(bilan.importedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "B4AFA6"))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func exportAndShare() {
        do {
            let payload = try BilanExportBuilder.build(context: context)
            let data = try BilanExportBuilder.encodeJSON(payload)
            let dateStamp = payload.exportedAt.formatted(.iso8601.year().month().day())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("bilan_export_\(dateStamp).json")
            try data.write(to: url, options: .atomic)
            shareItems = [BilanPrompt.text, url]
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            exportError = error.localizedDescription
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                exportError = "Impossible d'accéder au fichier sélectionné."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let title = "Bilan du \(Date.now.formatted(date: .abbreviated, time: .omitted))"
                let bilan = ArchivedBilan(title: title, pdfData: data)
                context.insert(bilan)
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}
