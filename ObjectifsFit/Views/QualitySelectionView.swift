import SwiftUI

/// Écran de sélection multiple des qualités physiques — poussé depuis le formulaire de cycle
/// plutôt que d'occuper toute la page (liste repliée dans le formulaire).
struct QualitySelectionView: View {
    let title: String
    @Binding var selection: Set<PhysicalQuality>

    var body: some View {
        List {
            ForEach(PhysicalQuality.allCases) { quality in
                Button {
                    if selection.contains(quality) {
                        selection.remove(quality)
                    } else {
                        selection.insert(quality)
                    }
                } label: {
                    HStack {
                        Text(quality.rawValue)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        if selection.contains(quality) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
