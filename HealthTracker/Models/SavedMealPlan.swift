import Foundation
import SwiftData

// A single saved weekly meal plan slot — kept separate from the ephemeral
// plan the Meal Plan screen generates, so regenerating/experimenting never
// overwrites what the user has explicitly chosen to keep. Saving again
// replaces this record; there's only ever one saved plan at a time.
@Model
final class SavedMealPlan {
    var id: UUID = UUID()
    var savedAt: Date = Date()
    var meals: [SuggestedMeal] = []
    var mealServings: [String: Double] = [:]

    init(meals: [SuggestedMeal], mealServings: [String: Double] = [:], savedAt: Date = Date()) {
        self.id = UUID()
        self.savedAt = savedAt
        self.meals = meals
        self.mealServings = mealServings
    }
}
