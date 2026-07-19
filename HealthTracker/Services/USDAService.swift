import Foundation

// USDA nutrient IDs we care about
private enum NutrientID: Int {
    case calcium    = 301
    case iron       = 303
    case magnesium  = 304
    case phosphorus = 305
    case potassium  = 306
    case sodium     = 307
    case zinc       = 309
    case vitaminC   = 401
    case vitaminB6  = 415
    case vitaminB12 = 418
    case vitaminA   = 320  // RAE µg
    case vitaminE   = 323
    case vitaminD   = 328  // µg
    case vitaminK   = 430
    case folate     = 435
    case omega3ALA  = 619  // 18:3 n-3
    case omega3EPA  = 629  // 20:5 n-3
    case omega3DHA  = 621  // 22:6 n-3
    case omega6     = 618  // 18:2 n-6

    var micronutrientKey: String {
        switch self {
        case .calcium:    return "calcium"
        case .iron:       return "iron"
        case .magnesium:  return "magnesium"
        case .phosphorus: return "phosphorus"
        case .potassium:  return "potassium"
        case .sodium:     return "sodium"
        case .zinc:       return "zinc"
        case .vitaminC:   return "vitamin_c"
        case .vitaminB6:  return "vitamin_b6"
        case .vitaminB12: return "vitamin_b12"
        case .vitaminA:   return "vitamin_a"
        case .vitaminE:   return "vitamin_e"
        case .vitaminD:   return "vitamin_d"
        case .vitaminK:   return "vitamin_k"
        case .folate:     return "folate"
        case .omega3ALA, .omega3EPA, .omega3DHA: return "omega_3"
        case .omega6:     return "omega_6"
        }
    }
}

private struct USDASearchResponse: Decodable {
    let foods: [USDAFood]
}

private struct USDAFood: Decodable {
    let fdcId: Int
    let description: String
    let foodNutrients: [USDANutrient]
}

private struct USDANutrient: Decodable {
    let nutrientId: Int
    let value: Double?
}

actor USDAService {
    static let shared = USDAService()
    private let base = "https://api.nal.usda.gov/fdc/v1"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    // Returns micronutrients keyed by our standard keys, values per 100g
    func fetchMicronutrients(for query: String) async -> [String: Double] {
        guard var components = URLComponents(string: "\(base)/foods/search") else { return [:] }
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "dataType", value: "SR Legacy,Foundation"),
            URLQueryItem(name: "pageSize", value: "1"),
            URLQueryItem(name: "api_key", value: Secrets.usdaAPIKey)
        ]
        guard let url = components.url else { return [:] }

        guard let (data, _) = try? await session.data(from: url),
              let response = try? JSONDecoder().decode(USDASearchResponse.self, from: data),
              let food = response.foods.first else { return [:] }

        return extractMicronutrients(from: food.foodNutrients)
    }

    private func extractMicronutrients(from nutrients: [USDANutrient]) -> [String: Double] {
        var result: [String: Double] = [:]

        for nutrient in nutrients {
            guard let id = NutrientID(rawValue: nutrient.nutrientId),
                  let value = nutrient.value else { continue }

            let key = id.micronutrientKey
            // Omega-3 comes from 3 separate fatty acids — sum them
            if key == "omega_3" {
                result[key] = (result[key] ?? 0) + value / 1000  // mg → g
            } else {
                result[key] = value
            }
        }

        return result
    }
}
