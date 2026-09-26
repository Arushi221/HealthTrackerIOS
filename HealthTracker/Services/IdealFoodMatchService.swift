import Foundation

private struct IndexedMatch: Decodable {
    let food: String
    let logIndices: [Int]
}

private struct MatchesPayload: Decodable {
    let matches: [IndexedMatch]
}

// Reads a person's logged meals and figures out which entries from their
// "ideal foods" wishlist actually showed up in them — a semantic match (e.g.
// "grilled salmon fillet" matches a wishlist entry of just "salmon") rather
// than the plain keyword search FoodCategoryGoal uses, since real logged
// ingredient names rarely match a short wishlist word for word.
actor IdealFoodMatchService {
    static let shared = IdealFoodMatchService()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    func findMatches(foods: [String], logs: [FoodLog]) async throws -> [IdealFoodMatch] {
        guard !Secrets.anthropicAPIKey.isEmpty, Secrets.anthropicAPIKey != "PASTE_YOUR_KEY_HERE" else {
            throw AnthropicServiceError.noAPIKey
        }
        guard !foods.isEmpty, !logs.isEmpty else { return [] }

        // Most recent first, capped so the prompt stays a reasonable size —
        // day/week/month progress only ever needs the last month anyway.
        let sortedLogs = logs.sorted { $0.loggedAt > $1.loggedAt }
        let cappedLogs = Array(sortedLogs.prefix(120))

        let isoFormatter = ISO8601DateFormatter()
        let mealLines = cappedLogs.enumerated().map { index, log -> String in
            let itemNames = log.meal.items.map(\.product.name).joined(separator: ", ")
            let ingredients = itemNames.isEmpty ? log.meal.name : itemNames
            return "[\(index)] \(isoFormatter.string(from: log.loggedAt)) \(log.meal.mealType.rawValue): \(log.meal.name) — ingredients: \(ingredients)"
        }.joined(separator: "\n")

        let userPrompt = """
        My wishlist of foods I'm trying to eat more of: \(foods.joined(separator: ", "))

        Here are meals I've actually logged, each with an index in brackets:
        \(mealLines)

        For each wishlist food, list the indices of every logged meal that contains it or a clear \
        equivalent (e.g. "salmon" matches "grilled salmon fillet" or "salmon salad"; "greek yogurt" \
        matches "plain greek yogurt bowl"). Be reasonably strict — don't match on a loose category \
        (e.g. "fish" shouldn't match every seafood dish unless "fish" itself is the wishlist word). \
        Include every wishlist food in your response even if it has no matches (empty index list).
        """

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(Secrets.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 4096,
            "system": "You are a nutrition assistant matching a person's food wishlist against their actual logged meals.",
            "messages": [["role": "user", "content": userPrompt]],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "matches": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "food": ["type": "string", "enum": foods],
                                        "logIndices": ["type": "array", "items": ["type": "integer"]]
                                    ],
                                    "required": ["food", "logIndices"],
                                    "additionalProperties": false
                                ]
                            ]
                        ],
                        "required": ["matches"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)

        guard let text = response.content.first(where: { $0.type == "text" })?.text,
              let textData = text.data(using: .utf8) else {
            throw AnthropicServiceError.emptyResponse
        }

        let payload = try JSONDecoder().decode(MatchesPayload.self, from: textData)

        var results: [IdealFoodMatch] = []
        for indexedMatch in payload.matches {
            for index in indexedMatch.logIndices where cappedLogs.indices.contains(index) {
                results.append(IdealFoodMatch(food: indexedMatch.food, loggedAt: cappedLogs[index].loggedAt))
            }
        }
        return results
    }
}
