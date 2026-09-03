import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
}

// A single product + how many servings were eaten
@Model
final class MealItem {
    var product: FoodProduct
    var servings: Double  // multiplier on the product's serving size

    var calories: Double { product.calories * servings }
    var protein: Double  { product.protein  * servings }
    var carbs: Double    { product.carbs    * servings }
    var fat: Double      { product.fat      * servings }
    var fiber: Double?   { product.fiber.map { $0 * servings } }
    var sugar: Double?   { product.sugar.map { $0 * servings } }

    func amount(of nutrientKey: String) -> Double {
    (product.micronutrients[nutrientKey] ?? 0) * servings
}


    init(product: FoodProduct, servings: Double = 1.0) {
        self.product = product
        self.servings = servings
    }
}

@Model
final class Meal {
    var id: UUID
    var name: String
    var mealType: MealType
    var items: [MealItem]
    var date: Date

    var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double  { items.reduce(0) { $0 + $1.protein  } }
    var totalCarbs: Double    { items.reduce(0) { $0 + $1.carbs    } }
    var totalFat: Double      { items.reduce(0) { $0 + $1.fat      } }
    // nil (not 0) when none of the items have fiber/sugar data at all,
    // so the detail view can distinguish "genuinely zero" from "unknown".
    var totalFiber: Double? {
        let values = items.compactMap(\.fiber)
        return values.isEmpty ? nil : values.reduce(0, +)
    }
    var totalSugar: Double? {
        let values = items.compactMap(\.sugar)
        return values.isEmpty ? nil : values.reduce(0, +)
    }
    func totalAmount(of nutrientKey: String) -> Double { items.reduce(0) { $0 + $1.amount(of: nutrientKey) } }

    init(name: String, mealType: MealType, items: [MealItem] = [], date: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.mealType = mealType
        self.items = items
        self.date = date
    }
}
