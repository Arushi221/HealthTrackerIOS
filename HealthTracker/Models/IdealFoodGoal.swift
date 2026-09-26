import Foundation
import SwiftData

// A goal built from foods you want to eat more of, picked by hand rather than
// drawn from a fixed catalog like FoodCategoryGoal. Matches are found by
// asking Claude to read your actual logged meals (so "grilled salmon fillet"
// matches a wishlist entry of just "salmon") rather than a local keyword
// search, since real ingredient names rarely match a short wishlist word for
// word — see IdealFoodMatchService.
@Model
final class IdealFoodGoal {
    var id: UUID
    var foods: [String]
    var dailyTarget: Int
    var isActive: Bool

    // Cached result of the last on-demand Claude check, so there's something
    // to show without re-calling the API on every view.
    var lastCheckedAt: Date?
    var matches: [IdealFoodMatch]

    init(foods: [String] = [], dailyTarget: Int = 2) {
        self.id = UUID()
        self.foods = foods
        self.dailyTarget = dailyTarget
        self.isActive = true
        self.lastCheckedAt = nil
        self.matches = []
    }
}

struct IdealFoodMatch: Codable, Hashable {
    let food: String
    let loggedAt: Date
}

extension IdealFoodGoal {
    func progress(for period: GoalPeriod) -> FoodCategoryProgress {
        let interval = currentInterval(for: period)
        let count = matches.filter { interval.contains($0.loggedAt) }.count
        let days = interval.duration / 86400
        let target = Int((Double(dailyTarget) * days).rounded())
        return FoodCategoryProgress(count: count, target: target)
    }
}
