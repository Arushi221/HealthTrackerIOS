import Foundation

private struct FoodListPayload: Decodable {
    let foods: [String]
}

// Asks Claude for a keyword list of foods for a given category (brain health,
// thyroid support, etc). Uses Haiku — this is a short, simple list-generation
// task, not worth a bigger model.
actor FoodCategoryService {
    static let shared = FoodCategoryService()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: config)
    }

    func fetchFoods(for category: FoodCategory) async throws -> [String] {
        guard !Secrets.anthropicAPIKey.isEmpty, Secrets.anthropicAPIKey != "PASTE_YOUR_KEY_HERE" else {
            throw AnthropicServiceError.noAPIKey
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(Secrets.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let userPrompt = "List 25 \(category.promptTopic) as short lowercase keywords. No brand names."

        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 1024,
            "system": "You are a nutrition assistant.",
            "messages": [["role": "user", "content": userPrompt]],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": [
                        "type": "object",
                        "properties": [
                            "foods": ["type": "array", "items": ["type": "string"]]
                        ],
                        "required": ["foods"],
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

        return try JSONDecoder().decode(FoodListPayload.self, from: textData).foods
    }
}
