import Foundation
import SwiftData

@Model
final class NutrientGoal {
    var id: UUID
    var nutrientKey: String     // e.g. "vitamin_d" — matches FoodProduct.micronutrients' keys
    var displayName: String     // e.g. "Vitamin D" — shown in the UI
    var unit: String            // e.g. "µg" — shown next to numbers in the UI
    var dailyTarget: Double     // the number the user sets, e.g. 20.0
    var isActive: Bool

    init(
        nutrientKey: String,
        displayName: String,
        unit: String,
        dailyTarget: Double
    ) {
        self.id = UUID()
        self.nutrientKey = nutrientKey
        self.displayName = displayName
        self.unit = unit
        self.dailyTarget = dailyTarget
        self.isActive = true
    }
}
