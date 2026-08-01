import Foundation

struct NutrientGoalSuggestion: Decodable, Identifiable {
    let nutrientKey: String
    let dailyTarget: Double
    let rationale: String

    var id: String { nutrientKey }
}

private struct SuggestionsPayload: Decodable {
    let suggestions: [NutrientGoalSuggestion]
}

// Turns lab results into suggested daily nutrient targets — constrained to the
// nutrients this app already knows how to track, via a JSON schema enum, so
// Claude can never suggest a key the rest of the app doesn't understand.
actor NutrientGoalSuggestionService {
    static let shared = NutrientGoalSuggestionService()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func suggestGoals(from labResults: [LabResult]) async throws -> [NutrientGoalSuggestion] {
        guard !Secrets.anthropicAPIKey.isEmpty, Secrets.anthropicAPIKey != "PASTE_YOUR_KEY_HERE" else {
            throw AnthropicServiceError.noAPIKey
        }
        guard !labResults.isEmpty else { return [] }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(Secrets.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let labSummary = labResults.map { result -> String in
            var line = "\(result.testName): \(result.value) \(result.unit)"
            if let low = result.referenceLow, let high = result.referenceHigh {
                line += " (reference \(low)-\(high), \(result.isInRange ? "in range" : "OUT OF RANGE"))"
            }
            return line
        }.joined(separator: "\n")

        let nutrientMenu = NutrientCatalog.all
            .map { "\($0.key): \($0.displayName) (\($0.unit))" }
            .joined(separator: "\n")
        let allowedKeys = NutrientCatalog.all.map(\.key)

        let userPrompt = """
        Here are my most recent lab results:
        \(labSummary)

        Nutrients I can set a daily goal for:
        \(nutrientMenu)

        Suggest daily targets only for nutrients from that list that are relevant to these specific \
        lab results (e.g. low iron -> suggest an iron target; elevated A1c or triglycerides -> suggest \
        lowering added sugar). Skip nutrients with no clear connection to these results. Keep the \
        rationale to one short sentence citing the specific lab value.
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 1536,
            "system": "You are a nutrition assistant suggesting general dietary nutrient targets based on lab results context. You are not providing medical diagnosis or treatment.",
            "messages": [["role": "user", "content": userPrompt]],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "suggestions": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "nutrientKey": ["type": "string", "enum": allowedKeys],
                                        "dailyTarget": ["type": "number"],
                                        "rationale": ["type": "string"]
                                    ],
                                    "required": ["nutrientKey", "dailyTarget", "rationale"],
                                    "additionalProperties": false
                                ]
                            ]
                        ],
                        "required": ["suggestions"],
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

        return try JSONDecoder().decode(SuggestionsPayload.self, from: textData).suggestions
    }
}
