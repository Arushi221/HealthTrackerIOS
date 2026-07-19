import Foundation
import SwiftData

@Model
final class FoodProduct {
    var id: UUID
    var name: String
    var brand: String?
    var barcode: String?

    // Serving
    var servingAmount: Double
    var servingUnit: String  // "g", "oz", "ml", "cup", etc.

    // Macros per serving
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sugar: Double?

    // Micronutrients stored as key-value (e.g. "sodium": 140)
    var micronutrients: [String: Double]

    // Allergen tags (e.g. "gluten", "dairy", "nuts", "soy")
    var allergens: [String]

    var dateAdded: Date

    init(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        servingAmount: Double = 100,
        servingUnit: String = "g",
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double? = nil,
        sugar: Double? = nil,
        micronutrients: [String: Double] = [:],
        allergens: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.servingAmount = servingAmount
        self.servingUnit = servingUnit
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.micronutrients = micronutrients
        self.allergens = allergens
        self.dateAdded = Date()
    }
}
