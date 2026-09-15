import Foundation

/// Qualité physique pouvant être visée par un cycle ou une séance — sert à donner une raison
/// d'être à chaque séance plutôt que de la définir uniquement par groupe musculaire/activité.
enum PhysicalQuality: String, Codable, CaseIterable, Identifiable {
    case force = "Force"
    case hypertrophie = "Hypertrophie"
    case enduranceMusculaire = "Endurance musculaire"
    case explosivitePuissance = "Explosivité/puissance"
    case agiliteCoordination = "Agilité/coordination"
    case enduranceAerobie = "Endurance aérobie"
    case seuil = "Seuil"
    case vo2max = "VO2max"
    case maintien = "Maintien"
    case recuperationMobilite = "Récupération/mobilité"

    var id: String { rawValue }
}
