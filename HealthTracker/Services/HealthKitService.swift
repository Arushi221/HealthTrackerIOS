import Foundation
import HealthKit

enum HealthKitError: Error, LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Health data isn't available on this device."
        }
    }
}

actor HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)

    // Read-only — this app never writes to HealthKit
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.notAvailable }
        try await store.requestAuthorization(toShare: [], read: [activeEnergyType])
    }

    // Sum of Apple Watch active energy (workouts + general activity) for the given day
    func activeEnergyBurned(on date: Date) async throws -> Double {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .day, for: date) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: activeEnergyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let kcal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kcal)
            }
            store.execute(query)
        }
    }
}
