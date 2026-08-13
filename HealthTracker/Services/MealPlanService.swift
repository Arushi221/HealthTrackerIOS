import Foundation

struct SuggestedMeal: Codable, Identifiable, Hashable {
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

extension Array where Element == SuggestedMeal {
    // Rescales each day's meals so protein/carbs/fat sum to exactly the
    // day's goal (preserving each meal's relative share of that macro within
    // the day), then recomputes calories from the rescaled macros. This
    // guarantees two things at once: the day's totals sync with the goal,
    // and every meal's own calories stay consistent with its own macros
    // (4 kcal/g protein and carbs, 9 kcal/g fat) — rather than trusting the
    // model's independent, occasionally-inconsistent estimates for either.
    func syncedToDaily(goal: Goal) -> [SuggestedMeal] {
        let byDay = Dictionary(grouping: self, by: \.day)
        var result: [SuggestedMeal] = []
        for day in byDay.keys.sorted() {
            guard let meals = byDay[day] else { continue }

            let totalProtein = meals.reduce(0) { $0 + $1.protein }
            let totalCarbs = meals.reduce(0) { $0 + $1.carbs }
            let totalFat = meals.reduce(0) { $0 + $1.fat }

            let proteinScale = totalProtein > 0 ? goal.targetProtein / totalProtein : 1
            let carbsScale = totalCarbs > 0 ? goal.targetCarbs / totalCarbs : 1
            let fatScale = totalFat > 0 ? goal.targetFat / totalFat : 1

            for meal in meals {
                let protein = meal.protein * proteinScale
                let carbs = meal.carbs * carbsScale
                let fat = meal.fat * fatScale
                result.append(SuggestedMeal(
                    day: meal.day,
                    mealType: meal.mealType,
                    name: meal.name,
                    description: meal.description,
                    calories: protein * 4 + carbs * 4 + fat * 9,
                    protein: protein,
                    carbs: carbs,
                    fat: fat
                ))
            }
        }
        return result
    }
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

struct ShoppingList {
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

private struct ShoppingListItemsPayload: Decodable {
    let items: [ShoppingListItem]
}

// Generates a week of meal suggestions from a person's macro goals, lab
// results, allergen exclusions, and grocery budget, plus on-demand recipes
// and a store-grouped shopping list for a set of planned meals.
actor MealPlanService {
    static let shared = MealPlanService()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 150
        self.session = URLSession(configuration: config)
    }

    func generateWeeklyPlan(goal: Goal, labResults: [LabResult], profile: UserProfile?, customInstructions: String = "") async throws -> [SuggestedMeal] {
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

        // Snack is small; breakfast/lunch/dinner split the rest roughly evenly.
        let snackCalories = (goal.targetCalories * 0.12).rounded()
        let mainMealCalories = ((goal.targetCalories - snackCalories) / 3).rounded()

        let cuisineLine = (profile?.preferIndianMediterranean ?? false)
            ? "Primarily Indian and Mediterranean cuisine — think dals, curries, tikka, biryani-style grain bowls, chana/rajma, Greek- and Levantine-style dishes, hummus and falafel, olive-oil- and lemon-forward salads, grilled meats with tzatziki, etc. Most meals across the week should draw from these two cuisines; occasional variety outside them is fine but should stay the minority."
            : "No specific cuisine preference — use a normal variety of everyday meals."

        let trimmedCustomInstructions = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let customInstructionsBlock = trimmedCustomInstructions.isEmpty
            ? ""
            : """


            One more thing — the user typed this custom request for this specific plan, so follow it \
            closely and let it override any of the general guidance above where they conflict (except \
            the allergens to avoid, which are a hard safety constraint no matter what): \
            "\(trimmedCustomInstructions)"
            """

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
        Cuisine preference: \(cuisineLine)

        Meal sizing: breakfast, lunch, and dinner should each be close to \(Int(mainMealCalories)) kcal \
        (roughly equal to each other, within about 15%) — don't make one meal much larger than the \
        others. The snack should be small, around \(Int(snackCalories)) kcal — not a large snack.

        This is for meal prepping, so it's fine — even encouraged — to repeat the same recipe across \
        multiple days (e.g. the same lunch for 3-4 days in a row) rather than needing something \
        different every single day. For each meal, give a realistic name, a one-sentence description \
        of what's in it, and its estimated calories/protein/carbs/fat. The calories must be \
        consistent with the macros: protein grams × 4, plus carbs grams × 4, plus fat grams × 9 \
        should equal the calories you give (within rounding) — don't report a calorie number that \
        doesn't match the macros. Never include an avoided allergen or its common aliases.\
        \(customInstructionsBlock)
        """

        let mealTypes = MealType.allCases.map(\.rawValue)

        let body: [String: Any] = [
            "model": "claude-opus-5",
            "max_tokens": 10000,
            "system": "You are a nutrition assistant suggesting a week of meals that fit a person's macro targets, lab results, food restrictions, and grocery budget. You are not providing medical advice.",
            "messages": [["role": "user", "content": userPrompt]],
            "output_config": [
                "effort": "low",
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

        // 7 days x 4 meal types = 28. Retry if a run comes back short instead
        // of making the user wait through a slow effort level "just in case".
        let expectedMeals = 7 * MealType.allCases.count
        let minAcceptableMeals = expectedMeals / 2  // a badly-thin plan isn't usable — surface an error rather than showing it
        var bestMeals: [SuggestedMeal] = []
        for _ in 0..<4 {
            let payload: WeeklyPlanPayload = try await send(body: body)
            if payload.meals.count > bestMeals.count {
                bestMeals = payload.meals
            }
            if bestMeals.count >= expectedMeals { break }
        }

        guard bestMeals.count >= minAcceptableMeals else {
            throw AnthropicServiceError.incompleteResponse
        }
        return bestMeals.syncedToDaily(goal: goal)
    }

    func generateRecipe(for meal: SuggestedMeal, servings: Double, allergensToAvoid: [String]) async throws -> Recipe {
        let allergenLine = allergensToAvoid.isEmpty ? "None." : allergensToAvoid.joined(separator: ", ")
        let servingsWord = servings == 1 ? "1 serving" : "\(servings.formatted()) servings"

        let userPrompt = """
        Give a simple home-cook recipe for this meal, scaled to make \(servingsWord):
        Name: \(meal.name)
        Description: \(meal.description)
        Per-serving macros: \(Int(meal.calories)) kcal, \(Int(meal.protein))g protein, \(Int(meal.carbs))g carbs, \(Int(meal.fat))g fat

        Allergens/ingredients to strictly avoid: \(allergenLine)

        List the ingredients with quantities scaled for \(servingsWord) total (not per-serving \
        quantities), and short numbered-style step instructions for cooking that full batch. Include \
        a rough estimated total cost in USD to make all \(servingsWord).
        """

        let body: [String: Any] = [
            "model": "claude-opus-5",
            "max_tokens": 4096,
            "system": "You are a home-cooking assistant writing simple, realistic recipes.",
            "messages": [["role": "user", "content": userPrompt]],
            "output_config": [
                "effort": "low",
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

    func generateShoppingList(for meals: [SuggestedMeal], servings: [String: Double], profile: UserProfile?) async throws -> ShoppingList {
        let mealLines = meals.map { meal -> String in
            let s = servings[meal.id] ?? 1.0
            let servingsNote = s == 1.0 ? "" : " [make \(s.formatted()) servings of this]"
            return "Day \(meal.day) \(meal.mealType): \(meal.name) — \(meal.description)\(servingsNote)"
        }.joined(separator: "\n")

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
        Build a consolidated shopping list for this exact week of meals — nothing more, nothing less:
        \(mealLines)

        List every ingredient needed to cook every single meal above. Do not skip any meal, and do \
        not stop before covering all \(meals.count) meals — a full week like this typically needs \
        20-40+ distinct grocery items, so a short list means you missed meals. Some meals are \
        tagged "[make N servings of this]" — scale that meal's ingredient quantities by N before \
        combining with everything else; meals without a tag are a single serving. Combine repeated \
        ingredients across meals into single line items with a combined quantity (e.g. "6 eggs" not \
        "2 eggs" three separate times). Only include ingredients these specific meals actually need — \
        don't add unrelated pantry staples.

        Stores this person shops at: \(storeLine)
        Weekly grocery budget: \(budgetLine)

        For each item, assign the store it's best bought from (from the list above, or a sensible \
        generic store type if none were given), a grocery department, and an estimated cost in USD.
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
            "max_tokens": 8000,
            "system": "You are a grocery planning assistant that turns a week of meals into a complete, consolidated, store-grouped shopping list. Missing ingredients or stopping early is the most common mistake — always cover every meal you were given.",
            "messages": [["role": "user", "content": userPrompt]],
            "output_config": [
                "effort": "low",
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
                            ]
                        ],
                        "required": ["items"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]

        // Claude occasionally bails early on this task (a handful of items
        // instead of a full week's worth), even with plenty of token budget
        // left — retry a couple of times if the result looks implausibly short.
        let minExpectedItems = max(8, meals.count)
        var bestItems: [ShoppingListItem] = []
        for attempt in 0..<3 {
            let payload: ShoppingListItemsPayload = try await send(body: body)
            if payload.items.count > bestItems.count {
                bestItems = payload.items
            }
            if bestItems.count >= minExpectedItems {
                break
            }
            if attempt < 2 { continue }
        }

        guard !bestItems.isEmpty else {
            throw AnthropicServiceError.emptyResponse
        }

        let total = bestItems.reduce(0) { $0 + $1.estimatedCost }
        let withinBudget = (profile?.weeklyBudget ?? 0) <= 0 || total <= (profile?.weeklyBudget ?? 0)

        return ShoppingList(items: bestItems, estimatedTotalCost: total, withinBudget: withinBudget)
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
