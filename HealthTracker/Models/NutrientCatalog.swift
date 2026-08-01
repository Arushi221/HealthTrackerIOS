import Foundation

struct TrackedNutrient: Identifiable, Hashable {
    let key: String
    let displayName: String
    let unit: String

    var id: String { key }
}

enum NutrientCatalog {
    static let all: [TrackedNutrient] = [
        TrackedNutrient(key: "calcium", displayName: "Calcium", unit: "mg"),
        TrackedNutrient(key: "iron", displayName: "Iron", unit: "mg"),
        TrackedNutrient(key: "magnesium", displayName: "Magnesium", unit: "mg"),
        TrackedNutrient(key: "potassium", displayName: "Potassium", unit: "mg"),
        TrackedNutrient(key: "zinc", displayName: "Zinc", unit: "mg"),
        TrackedNutrient(key: "vitamin_a", displayName: "Vitamin A", unit: "µg"),
        TrackedNutrient(key: "vitamin_c", displayName: "Vitamin C", unit: "mg"),
        TrackedNutrient(key: "vitamin_d", displayName: "Vitamin D", unit: "µg"),
        TrackedNutrient(key: "vitamin_e", displayName: "Vitamin E", unit: "mg"),
        TrackedNutrient(key: "vitamin_k", displayName: "Vitamin K", unit: "µg"),
        TrackedNutrient(key: "vitamin_b6", displayName: "Vitamin B6", unit: "mg"),
        TrackedNutrient(key: "vitamin_b12", displayName: "Vitamin B12", unit: "µg"),
        TrackedNutrient(key: "folate", displayName: "Folate", unit: "µg"),
        TrackedNutrient(key: "added_sugar", displayName: "Added Sugar", unit: "g"),
        TrackedNutrient(key: "omega_3", displayName: "Omega-3", unit: "g")
    ]
}
