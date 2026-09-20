import Foundation
import SwiftData

/// Un bilan PDF reçu de Claude et archivé dans l'app pour relecture — import manuel uniquement
/// (bouton "Importer un bilan"), aucune génération ni round-trip automatique.
@Model
final class ArchivedBilan {
    var id: UUID
    var title: String
    var importedAt: Date
    var pdfData: Data

    /// Rattachement optionnel à un cycle/programme précis (import depuis leur propre bouton
    /// "Importer le bilan" plutôt que depuis le Tableau de bord) — id conservé pour retrouver ce
    /// bilan depuis la page du cycle/programme, `linkLabel` capturé à l'import pour que le badge
    /// reste affichable même si le cycle/programme est supprimé ensuite.
    var linkedCycleId: UUID?
    var linkedProgramId: UUID?
    var linkLabel: String?

    init(title: String, importedAt: Date = .now, pdfData: Data, linkedCycleId: UUID? = nil, linkedProgramId: UUID? = nil, linkLabel: String? = nil) {
        self.id = UUID()
        self.title = title
        self.importedAt = importedAt
        self.pdfData = pdfData
        self.linkedCycleId = linkedCycleId
        self.linkedProgramId = linkedProgramId
        self.linkLabel = linkLabel
    }
}
