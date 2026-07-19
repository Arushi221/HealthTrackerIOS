import Foundation
import SwiftData

// One logged meal on a specific day, tied to an active goal period
@Model
final class FoodLog {
    var id: UUID
    var meal: Meal
    var loggedAt: Date
    var goalId: UUID  // which Goal this log contributes toward

    init(meal: Meal, goalId: UUID, loggedAt: Date = Date()) {
        self.id = UUID()
        self.meal = meal
        self.loggedAt = loggedAt
        self.goalId = goalId
    }
}
