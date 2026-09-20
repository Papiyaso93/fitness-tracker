import SwiftUI
import UIKit

/// Partage natif texte + fichier ensemble (prompt + export JSON) — `ShareLink` ne gère pas bien
/// un tableau hétérogène de types différents, alors qu'`UIActivityViewController` le fait nativement.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
