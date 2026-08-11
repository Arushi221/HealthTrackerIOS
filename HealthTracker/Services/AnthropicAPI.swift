import Foundation

// Shared response shape for calls to the Anthropic Messages API — used by
// any service that talks to Claude (FoodCategoryService, NutrientGoalSuggestionService, ...)
struct AnthropicContentBlock: Decodable {
    let type: String
    let text: String?
}

struct AnthropicMessageResponse: Decodable {
    let content: [AnthropicContentBlock]
}

enum AnthropicServiceError: Error, LocalizedError {
    case noAPIKey
    case emptyResponse
    case incompleteResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Add your Anthropic API key to Secrets.swift."
        case .emptyResponse: return "No response from Claude."
        case .incompleteResponse: return "Claude's response was incomplete. Please try again."
        }
    }
}
