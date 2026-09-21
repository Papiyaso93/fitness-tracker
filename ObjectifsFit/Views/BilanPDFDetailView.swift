import SwiftUI
import PDFKit

private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct BilanPDFDetailView: View {
    let bilan: ArchivedBilan

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showsDeleteConfirmation = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            PDFKitView(data: bilan.pdfData)
                .background(AppTheme.background)
                .navigationTitle(bilan.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showsDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            share()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .confirmationDialog("Supprimer ce bilan ?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
                    Button("Supprimer", role: .destructive) {
                        context.delete(bilan)
                        dismiss()
                    }
                    Button("Annuler", role: .cancel) {}
                }
                .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
                    if let shareURL {
                        ShareSheet(activityItems: [shareURL])
                    }
                }
        }
    }

    /// Partage/enregistrement du PDF — passe par un fichier temporaire nommé plutôt que les `Data`
    /// brutes, sinon la feuille de partage propose un nom générique sans extension .pdf.
    private func share() {
        let filename = bilan.title.hasSuffix(".pdf") ? bilan.title : "\(bilan.title).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? bilan.pdfData.write(to: url, options: .atomic)
        shareURL = url
    }
}
