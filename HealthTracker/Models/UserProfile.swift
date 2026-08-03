import Foundation
import SwiftData

// A single settings record for the whole app — grocery budget and preferred
// stores, used by the meal planner and shopping list.
@Model
final class UserProfile {
    var id: UUID
    var weeklyBudget: Double
    var preferredStores: [String]

    init(weeklyBudget: Double = 0, preferredStores: [String] = []) {
        self.id = UUID()
        self.weeklyBudget = weeklyBudget
        self.preferredStores = preferredStores
    }
}
