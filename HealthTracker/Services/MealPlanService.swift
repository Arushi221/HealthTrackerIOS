import Foundation

struct SuggestedMeal: Decodable, Identifiable, Hashable {
    let day: Int  // 0 = today ... 6 = six days from today
    let mealType: String
    let name: String
    let description: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    var id: String { "\(day)-\(mealType)-\(name)" }
}

struct Recipe: Decodable {
    let ingredients: [String]
    let instructions: [String]
    let estimatedCost: Double?
}

struct ShoppingListItem: Decodable, Identifiable {
    let name: String
    let quantity: String
    let store: String
    let department: String
    let estimatedCost: Double

    var id: String { store + department + name }
}

struct ShoppingList: Decodable {
    let items: [ShoppingListItem]
    let estimatedTotalCost: Double
    let withinBudget: Bool

    var byStore: [(store: String, items: [ShoppingListItem])] {
        let grouped = Dictionary(grouping: items, by: \.store)
        return grouped.keys.sorted().map { store in
            (store, grouped[store]!.sorted { $0.department < $1.department })
        }
    }
}

private struct WeeklyPlanPayload: Decodable {
    let meals: [SuggestedMeal]
}

// Generates a week of meal suggestions from a person's macro goals, lab
// results, allergen exclusions, and grocery budget, plus on-demand recipes
// and a store-grouped shopping list for a set of planned meals.
actor MealPlanService {
    static let shared = MealPlanService()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    func generateWeeklyPlan(goal: Goal, labResults: [LabResult], profile: UserProfile?) async throws -> [SuggestedMeal] {
        let allergenLine = goal.excludedAllergens.isEmpty
            ? "None."
            : goal.excludedAllergens.joined(separator: ", ")
        let preferredLine = goal.preferredFoods.isEmpty
            ? "None specified."
            : goal.preferredFoods.joined(separator: ", ")

        let labLine: String
        if labResults.isEmpty {
            labLine = "None available."
        } else {
            labLine = labResults.map { result -> String in
                var line = "\(result.testName): \(result.value) \(result.unit)"
                if let low = result.referenceLow, let high = result.referenceHigh {
                    line += " (reference \(low)-\(high), \(result.isInRange ? "in range" : "OUT OF RANGE"))"
                }
                return line
            }.joined(separator: "\n")
        }

        let budgetLine: String
        if let profile, profile.weeklyBudget > 0 {
            budgetLine = "$\(Int(profile.weeklyBudget)) for the whole week of groceries. Favor budget-friendly ingredients that keep the week's estimated grocery cost within this amount."
        } else {
            budgetLine = "No specific budget set."
        }

        let userPrompt = """
        Suggest a full week (7 days, day index 0 through 6) of meals — one breakfast, one lunch, \
        one dinner, and one snack per day — that together approximate these daily targets:
        Calories: \(Int(goal.targetCalories)) kcal
        Protein: \(Int(goal.targetProtein)) g
        Carbs: \(Int(goal.targetCarbs)) g
        Fat: \(Int(goal.targetFat)) g

        Allergens/ingredients to strictly avoid in every meal: \(allergenLine)
        Preferred foods to favor when reasonable: \(preferredLine)
        Recent lab results to take into account when choosing foods (e.g. suggest iron-rich foods \
        for low iron, lower added sugar for elevated A1c/triglycerides, etc.): \(labLine)
        Weekly grocery budget: \(budgetLine)

        Vary the meals across the week rather than repeating the same thing every day. For each \
        meal, give a realistic name, a one-sentence description of what's in it, and its estimated \
        calories/protein/carbs/fat. Never include an avoided allergen or its common aliases.
        """

        let mealTypes = MealType.allCases.map(\.rawValue)

        let body: [String: Any] = [
            "model": "claude-opus-5",
            "max_tokens": 8000,
            "system": "You are a nutrition assistant suggesting a week of meals that fit a person's macro targets, lab results, food restrictions, and grocery budget. You are not providing medical advice.",
            "messages": [["role": "user", "content": userPrompt]],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "meals": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "day": ["type": "integer", "enum": [0, 1, 2, 3, 4, 5, 6]],
                                        "mealType": ["type": "string", "enum": mealTypes],
                                        "name": ["type": "string"],
                                        "description": ["type": "string"],
                                        "calories": ["type": "number"],
                                        "protein": ["type": "number"],
                                        "carbs": ["type": "number"],
                                        "fat": ["type": "number"]
                                    ],
                                    "required": ["day", "mealType", "name", "description", "calories", "protein", "carbs", "fat"],
                                    "additionalProperties": false
                                ]
                            ]
                        ],
                        "required": ["meals"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]

        let payload: WeeklyPlanPayload = try await send(body: body)
        return payload.meals
    }

    func generateRecipe(for meal: SuggestedMeal, allergensToAvoid: [String]) async throws -> Recipe {
        let allergenLine = allergensToAvoid.isEmpty ? "None." : allergensToAvoid.joined(separator: ", ")

        let userPrompt = """
        Give a simple home-cook recipe for this meal:
        Name: \(meal.name)
        Description: \(meal.description)
        Target macros: \(Int(meal.calories)) kcal, \(Int(meal.protein))g protein, \(Int(meal.carbs))g carbs, \(Int(meal.fat))g fat

        Allergens/ingredients to strictly avoid: \(allergenLine)

        List the ingredients with quantities, and short numbered-style step instructions. Include \
        a rough estimated cost in USD to make this single serving.
        """

        let body: [String: Any] = [
            "model": "claude-opus-5",
            "max_tokens": 1536,
            "system": "You are a home-cooking assistant writing simple, realistic recipes.",
            "messages": [["role": "user", "content": userPrompt]],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "ingredients": ["type": "array", "items": ["type": "string"]],
                            "instructions": ["type": "array", "items": ["type": "string"]],
                            "estimatedCost": ["type": "number"]
                        ],
                        "required": ["ingredients", "instructions", "estimatedCost"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]

        return try await send(body: body)
    }

    func generateShoppingList(for meals: [SuggestedMeal], profile: UserProfile?) async throws -> ShoppingList {
        let mealLines = meals.map { "Day \($0.day) \($0.mealType): \($0.name) — \($0.description)" }.joined(separator: "\n")

        let storeLine: String
        if let profile, !profile.preferredStores.isEmpty {
            storeLine = profile.preferredStores.joined(separator: ", ")
        } else {
            storeLine = "None specified — group by a generic store type instead (e.g. \"Grocery Store\", \"Butcher\", \"Farmers Market\")."
        }

        let budgetLine: String
        if let profile, profile.weeklyBudget > 0 {
            budgetLine = "$\(Int(profile.weeklyBudget)) for the week."
        } else {
            budgetLine = "No specific budget set — just estimate honestly."
        }

        let userPrompt = """
        Build a consolidated shopping list for this week of meals:
        \(mealLines)

        Combine repeated ingredients across meals into single line items with a total quantity. \
        Stores this person shops at: \(storeLine)
        Weekly grocery budget: \(budgetLine)

        For each item, assign the store it's best bought from (from the list above, or a sensible \
        generic store type if none were given) and a grocery department. Give an estimated cost \
        per item in USD, and a total estimated cost for the whole list. Set withinBudget to true \
        only if the total is at or under the stated budget (or if no budget was given).
        """

        let departmentEnum = ["Produce", "Dairy", "Meat & Seafood", "Bakery", "Pantry", "Frozen", "Other"]

        var itemProperties: [String: Any] = [
            "name": ["type": "string"],
            "quantity": ["type": "string"],
            "department": ["type": "string", "enum": departmentEnum],
            "estimatedCost": ["type": "number"]
        ]
        if let profile, !profile.preferredStores.isEmpty {
            itemProperties["store"] = ["type": "string", "enum": profile.preferredStores]
        } else {
            itemProperties["store"] = ["type": "string"]
        }

        let body: [String: Any] = [
            "model": "claude-opus-5",
            "max_tokens": 4096,
            "system": "You are a grocery planning assistant that turns a week of meals into a consolidated, store-grouped shopping list within budget.",
            "messages": [["role": "user", "content": userPrompt]],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "items": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": itemProperties,
                                    "required": ["name", "quantity", "store", "department", "estimatedCost"],
                                    "additionalProperties": false
                                ]
                            ],
                            "estimatedTotalCost": ["type": "number"],
                            "withinBudget": ["type": "boolean"]
                        ],
                        "required": ["items", "estimatedTotalCost", "withinBudget"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]

        return try await send(body: body)
    }

    private func send<T: Decodable>(body: [String: Any]) async throws -> T {
        guard !Secrets.anthropicAPIKey.isEmpty, Secrets.anthropicAPIKey != "PASTE_YOUR_KEY_HERE" else {
            throw AnthropicServiceError.noAPIKey
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(Secrets.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)

        guard let text = response.content.first(where: { $0.type == "text" })?.text,
              let textData = text.data(using: .utf8) else {
            throw AnthropicServiceError.emptyResponse
        }

        return try JSONDecoder().decode(T.self, from: textData)
    }
}
