import Foundation
import SwiftUI

enum ResistanceMode: String, Codable, CaseIterable {
    case poidsLibre = "Poids libre"
    case machine = "Machine"
    case poidsDuCorps = "Poids du corps"
    case leste = "Lesté"
    case elastique = "Élastique"

    /// Le poids en kg n'a de sens comparable que pour ces modes — l'élastique est exclu
    /// du tonnage/charge moyenne car il n'existe pas de correspondance kg fiable.
    var comparableToKilograms: Bool { self != .elastique }
}

enum SensationLevel: Int, Codable, CaseIterable, Hashable {
    case facile = 0
    case confortable = 1
    case normal = 2
    case difficile = 3
    case tresDifficile = 4
    case echec = 5

    var label: String {
        switch self {
        case .facile: return "😌 Facile"
        case .confortable: return "🙂 Confortable"
        case .normal: return "😐 Normal"
        case .difficile: return "😤 Difficile"
        case .tresDifficile: return "🔥 Très difficile"
        case .echec: return "💀 Échec"
        }
    }

    var isHard: Bool { self == .difficile || self == .tresDifficile || self == .echec }

    /// Couleurs distinctes par niveau (pas un dégradé continu) — le gris signale un niveau neutre
    /// à peine notable, puis bleu/vert/jaune/orange/rouge montent en intensité perçue jusqu'à
    /// l'échec, pour visualiser d'un coup d'œil quand une semaine "monte dans le rouge".
    var color: Color {
        switch self {
        case .facile: return Color(hex: "C9C4B8")
        case .confortable: return Color(hex: "378ADD")
        case .normal: return Color(hex: "639922")
        case .difficile: return Color(hex: "F5C242")
        case .tresDifficile: return Color(hex: "EF9F27")
        case .echec: return Color(hex: "E24B4A")
        }
    }
}

enum SetTechnique: String, Codable, CaseIterable {
    case normal = "Normal"
    case superset = "Superset"
    case dropset = "Dropset"
    case autre = "Autre"

    /// Libellé affiché — distinct du rawValue stocké, pour pouvoir renommer l'affichage sans
    /// invalider les données déjà enregistrées.
    var label: String {
        switch self {
        case .normal: return "Classique"
        default: return rawValue
        }
    }
}
