import Foundation
import HealthKit

/// Lit poids/masse grasse/VO2max depuis Apple Santé quand disponible (balance Xiaomi/Zepp Life pour le poids,
/// montre connectée pour la VO2max). La masse grasse n'est pas garantie de remonter via Zepp Life :
/// la saisie manuelle reste toujours possible en secours (voir TodayView/GoalsView).
@MainActor
final class HealthKitManager: ObservableObject {
    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        if let vo2max = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2max)
        }
        return types
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func latestWeight() async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await latestQuantitySample(for: type, unit: .gramUnit(with: .kilo))
    }

    func latestBodyFatPercentage() async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) else { return nil }
        guard let fraction = await latestQuantitySample(for: type, unit: .percent()) else { return nil }
        return fraction * 100
    }

    func latestVO2Max() async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .vo2Max) else { return nil }
        let unit = HKUnit(from: "ml/kg*min")
        return await latestQuantitySample(for: type, unit: unit)
    }

    private func latestQuantitySample(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
