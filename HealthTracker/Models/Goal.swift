import Foundation
import SwiftData

enum GoalPeriod: String, Codable, CaseIterable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"
}

@Model
final class Goal {
    var id: UUID
    var period: GoalPeriod
    var startDate: Date

    // Macro targets
    var targetCalories: Double
    var targetProtein: Double
    var targetCarbs: Double
    var targetFat: Double

    // Food preferences
    var excludedAllergens: [String]
    var preferredFoods: [String]

    var isActive: Bool

    init(
        period: GoalPeriod,
        startDate: Date = Date(),
        targetCalories: Double,
        targetProtein: Double,
        targetCarbs: Double,
        targetFat: Double,
        excludedAllergens: [String] = [],
        preferredFoods: [String] = []
    ) {
        self.id = UUID()
        self.period = period
        self.startDate = startDate
        self.targetCalories = targetCalories
        self.targetProtein = targetProtein
        self.targetCarbs = targetCarbs
        self.targetFat = targetFat
        self.excludedAllergens = excludedAllergens
        self.preferredFoods = preferredFoods
        self.isActive = true
    }
}
