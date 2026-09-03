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

    // Optional weight-goal inputs used to derive targetCalories in the UI —
    // 0 means "not set" for maintenanceCalories, and 0 lbs/week for
    // weeklyWeightGoalLbs means "maintain". Kept around (rather than only
    // computing targetCalories once) so re-opening Edit Goal shows what was
    // actually picked instead of just the resulting number.
    var maintenanceCalories: Double = 0
    var weeklyWeightGoalLbs: Double = 0

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
        maintenanceCalories: Double = 0,
        weeklyWeightGoalLbs: Double = 0,
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
        self.maintenanceCalories = maintenanceCalories
        self.weeklyWeightGoalLbs = weeklyWeightGoalLbs
        self.excludedAllergens = excludedAllergens
        self.preferredFoods = preferredFoods
        self.isActive = true
    }
}
