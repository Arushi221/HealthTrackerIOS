import Foundation

extension Array where Element == FoodLog {
    func totalAmount(of nutrientKey: String, in interval: DateInterval) -> Double {
        let logsInRange = filter { interval.contains($0.loggedAt) }
        return logsInRange.reduce(0) { $0 + $1.meal.totalAmount(of: nutrientKey) }
    }



}

func currentInterval(for period: GoalPeriod, calendar: Calendar = .current) -> DateInterval {
    let component: Calendar.Component
    switch period {
    case .day:
        component = .day
    case .week:
        component = .weekOfYear
    case .month:
        component = .month
    }
    return calendar.dateInterval(of: component, for: Date())!
}

struct NutrientProgress {
    let consumed: Double
    let target: Double
}

extension NutrientGoal {
    func progress(for period: GoalPeriod, logs: [FoodLog]) -> NutrientProgress {
        let interval = currentInterval(for: period)
        let consumed = logs.totalAmount(of: nutrientKey, in: interval)
        let days = interval.duration / 86400
        let target = dailyTarget * days
        return NutrientProgress(consumed: consumed, target: target)
    }
}
