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
    private let stepCountType = HKQuantityType(.stepCount)

    // Read-only — this app never writes to HealthKit
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.notAvailable }
        try await store.requestAuthorization(toShare: [], read: [activeEnergyType, stepCountType])
    }

    // Sum of Apple Watch active energy (workouts + general activity) for the given day
    func activeEnergyBurned(on date: Date) async throws -> Double {
        try await sum(of: activeEnergyType, on: date, unit: .kilocalorie())
    }

    // Step count for the given day
    func stepCount(on date: Date) async throws -> Double {
        try await sum(of: stepCountType, on: date, unit: .count())
    }

    // Average daily steps over the trailing week (yesterday back `days` days,
    // excluding today since it's still in progress) — a steadier signal for
    // activity level than any single day, which can be thrown off by a rest
    // day or a single big workout.
    func averageDailySteps(trailingDays days: Int = 7) async throws -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var total = 0.0
        for offset in 1...days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            total += try await stepCount(on: day)
        }
        return total / Double(days)
    }

    private func sum(of quantityType: HKQuantityType, on date: Date, unit: HKUnit) async throws -> Double {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .day, for: date) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
