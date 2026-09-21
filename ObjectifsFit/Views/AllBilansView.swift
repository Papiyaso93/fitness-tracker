import SwiftUI
import SwiftData

/// Écran "Voir tout" des bilans archivés — la liste complète, contrairement à la carte compacte
/// du Tableau de bord qui ne montre que les 2 plus récents.
struct AllBilansView: View {
    @Query(sort: \ArchivedBilan.importedAt, order: .reverse) private var bilans: [ArchivedBilan]

    @State private var selectedBilan: ArchivedBilan?

    var body: some View {
        ScrollView {
            AppCard {
                VStack(spacing: 0) {
                    ForEach(Array(bilans.enumerated()), id: \.element.id) { index, bilan in
                        if index > 0 { Divider().overlay(AppTheme.border) }
                        Button {
                            selectedBilan = bilan
                        } label: {
                            BilanRowView(bilan: bilan)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("Bilans")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedBilan) { bilan in
            BilanPDFDetailView(bilan: bilan)
        }
    }
}
