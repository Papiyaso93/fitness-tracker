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
                }
                .confirmationDialog("Supprimer ce bilan ?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
                    Button("Supprimer", role: .destructive) {
                        context.delete(bilan)
                        dismiss()
                    }
                    Button("Annuler", role: .cancel) {}
                }
        }
    }
}
