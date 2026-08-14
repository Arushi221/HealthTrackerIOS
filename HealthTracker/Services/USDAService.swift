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

// Branded Foods search results — a different shape (and nutrient ID scheme)
// than the SR Legacy/Foundation search above.
private struct USDABrandedSearchResponse: Decodable {
    let foods: [USDABrandedFood]
}

private struct USDABrandedFood: Decodable {
    let servingSize: Double?
    let servingSizeUnit: String?
    let foodNutrients: [USDABrandedNutrient]
}

// Branded foods key their nutrients by "nutrientNumber" (a string, e.g.
// "203" for protein) rather than the "nutrientId" the SR Legacy/Foundation
// dataset uses — the two schemes don't share values, so this can't reuse
// USDANutrient/NutrientID above.
private struct USDABrandedNutrient: Decodable {
    let nutrientNumber: String?
    let value: Double?
}

struct USDAServingMatch {
    let servingAmount: Double
    let servingUnit: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
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

    // Fallback for when Open Food Facts has no serving size for a product.
    // USDA's Branded Foods dataset is sourced from manufacturer-submitted
    // nutrition labels and often has real serving data even when OFF
    // doesn't, especially for US products. Nutrient values in this search
    // response are per 100g — verified empirically (USDA's own "per
    // serving size measure" derivation label on these fields is misleading;
    // the numbers only make sense, and match plausible real values, when
    // treated as per 100g and scaled by servingSize/100 like everything
    // else in this app).
    func fetchServingInfo(for query: String) async -> USDAServingMatch? {
        guard var components = URLComponents(string: "\(base)/foods/search") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "dataType", value: "Branded"),
            URLQueryItem(name: "pageSize", value: "1"),
            URLQueryItem(name: "api_key", value: Secrets.usdaAPIKey)
        ]
        guard let url = components.url else { return nil }

        guard let (data, _) = try? await session.data(from: url),
              let response = try? JSONDecoder().decode(USDABrandedSearchResponse.self, from: data),
              let food = response.foods.first,
              let servingAmount = food.servingSize,
              let servingUnit = food.servingSizeUnit,
              servingAmount > 0 else { return nil }

        func value(for nutrientNumber: String) -> Double {
            food.foodNutrients.first(where: { $0.nutrientNumber == nutrientNumber })?.value ?? 0
        }

        let scale = servingAmount / 100.0
        return USDAServingMatch(
            servingAmount: servingAmount,
            servingUnit: servingUnit,
            calories: value(for: "208") * scale,
            protein: value(for: "203") * scale,
            carbs: value(for: "205") * scale,
            fat: value(for: "204") * scale
        )
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
