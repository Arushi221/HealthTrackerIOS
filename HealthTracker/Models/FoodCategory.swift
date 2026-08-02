import Foundation

// A trackable "eat more of these" food category — the AI-generated keyword
// list and per-category goal system are both generic over this.
struct FoodCategory: Identifiable, Hashable {
    let key: String
    let displayName: String
    let promptTopic: String

    var id: String { key }
}

enum FoodCategoryCatalog {
    static let all: [FoodCategory] = [
        FoodCategory(
            key: "brain_health",
            displayName: "Brain Health",
            promptTopic: "well-known brain-healthy foods (e.g. salmon, walnuts, blueberries, leafy greens)"
        ),
        FoodCategory(
            key: "thyroid_health",
            displayName: "Thyroid & Hashimoto's Support",
            promptTopic: "foods commonly recommended to support thyroid health and Hashimoto's thyroiditis — selenium-rich foods (brazil nuts, sardines), iodine sources (seaweed, iodized salt), zinc-rich foods, and anti-inflammatory whole foods"
        ),
        FoodCategory(
            key: "autoimmune_support",
            displayName: "Autoimmune Support",
            promptTopic: "foods commonly recommended for general autoimmune and anti-inflammatory support — omega-3 rich fish, turmeric, ginger, leafy greens, berries, and fermented foods"
        )
    ]
}

// Caches each category's AI-generated food list locally so we don't call the
// API on every app launch — refreshed weekly, or manually per category.
enum FoodCategoryCache {
    private static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60

    static func foods(for category: FoodCategory) -> [String] {
        UserDefaults.standard.stringArray(forKey: foodsKey(category)) ?? []
    }

    static func needsRefresh(for category: FoodCategory) -> Bool {
        guard let fetchedAt = UserDefaults.standard.object(forKey: fetchedAtKey(category)) as? Date else { return true }
        return Date().timeIntervalSince(fetchedAt) > refreshInterval
    }

    static func save(_ foods: [String], for category: FoodCategory) {
        UserDefaults.standard.set(foods, forKey: foodsKey(category))
        UserDefaults.standard.set(Date(), forKey: fetchedAtKey(category))
    }

    private static func foodsKey(_ category: FoodCategory) -> String { "foodCategory.\(category.key).foods" }
    private static func fetchedAtKey(_ category: FoodCategory) -> String { "foodCategory.\(category.key).fetchedAt" }
}

extension Array where Element == FoodLog {
    // Case-insensitive keyword match against each logged meal's name
    func matching(keywords: [String]) -> [FoodLog] {
        filter { log in
            let name = log.meal.name.lowercased()
            return keywords.contains { name.contains($0.lowercased()) }
        }
    }
}
