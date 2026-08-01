import Foundation

// Caches the AI-generated brain-healthy food list locally so we don't
// call the API on every app launch — refreshed weekly, or manually.
enum BrainFoodCache {
    private static let foodsKey = "brainHealthyFoods"
    private static let fetchedAtKey = "brainHealthyFoodsFetchedAt"
    private static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60

    static var foods: [String] {
        UserDefaults.standard.stringArray(forKey: foodsKey) ?? []
    }

    static var needsRefresh: Bool {
        guard let fetchedAt = UserDefaults.standard.object(forKey: fetchedAtKey) as? Date else { return true }
        return Date().timeIntervalSince(fetchedAt) > refreshInterval
    }

    static func save(_ foods: [String]) {
        UserDefaults.standard.set(foods, forKey: foodsKey)
        UserDefaults.standard.set(Date(), forKey: fetchedAtKey)
    }
}

extension Array where Element == FoodLog {
    // Case-insensitive keyword match against each logged meal's name
    func brainHealthyMatches(against keywords: [String]) -> [FoodLog] {
        filter { log in
            let name = log.meal.name.lowercased()
            return keywords.contains { name.contains($0.lowercased()) }
        }
    }
}
