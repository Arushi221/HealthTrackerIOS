import Foundation
import SwiftData

// One goal per food category (brain health, thyroid support, ...), matched by
// categoryKey against FoodCategoryCatalog — same pattern as NutrientGoal/NutrientCatalog.
@Model
final class FoodCategoryGoal {
    var id: UUID
    var categoryKey: String
    var dailyTarget: Int
    var isActive: Bool

    init(categoryKey: String, dailyTarget: Int) {
        self.id = UUID()
        self.categoryKey = categoryKey
        self.dailyTarget = dailyTarget
        self.isActive = true
    }
}

struct FoodCategoryProgress {
    let count: Int
    let target: Int
}

extension FoodCategoryGoal {
    func progress(for period: GoalPeriod, logs: [FoodLog], keywords: [String]) -> FoodCategoryProgress {
        let interval = currentInterval(for: period)
        let logsInRange = logs.filter { interval.contains($0.loggedAt) }
        let matches = logsInRange.matching(keywords: keywords)
        let days = interval.duration / 86400
        let target = Int((Double(dailyTarget) * days).rounded())
        return FoodCategoryProgress(count: matches.count, target: target)
    }
}
