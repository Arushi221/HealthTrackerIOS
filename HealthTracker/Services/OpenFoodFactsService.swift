import Foundation

struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let allergens: String?
    let servingSize: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case allergens
        case servingSize = "serving_size"
    }
}

// The search-a-licious service (search.openfoodfacts.org) returns a different shape
// than the single-product v2 API — "hits" instead of "products", and "brands" as an array.
private struct OFFSearchResponse: Decodable {
    let hits: [FailableDecodable<OFFSearchHit>]
}

// Wraps a Decodable so one malformed entry in an array doesn't sink the whole decode —
// OFF is community-submitted data and individual products are sometimes missing/malformed fields.
private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

private struct OFFSearchHit: Decodable {
    let code: String?
    let productName: String?
    let brands: [String]?
    let nutriments: OFFNutriments?
    let allergens: String?
    let servingSize: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case allergens
        case servingSize = "serving_size"
    }
}

struct OFFNutriments: Decodable {
    // Macros
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let addedSugars100g: Double?
    let saturatedFat100g: Double?
    let transFat100g: Double?

    // Minerals (mg per 100g unless noted)
    let sodium100g: Double?      // returned in g, converted on use
    let calcium100g: Double?
    let iron100g: Double?
    let potassium100g: Double?
    let magnesium100g: Double?
    let zinc100g: Double?
    let phosphorus100g: Double?

    // Vitamins
    let vitaminA100g: Double?    // µg
    let vitaminC100g: Double?    // mg
    let vitaminD100g: Double?    // µg
    let vitaminE100g: Double?    // mg
    let vitaminK100g: Double?    // µg
    let vitaminB12100g: Double?  // µg
    let vitaminB6100g: Double?   // mg
    let folate100g: Double?      // µg

    // Fatty acids
    let omega3100g: Double?      // g
    let omega6100g: Double?      // g

    enum CodingKeys: String, CodingKey {
        case energyKcal100g    = "energy-kcal_100g"
        case proteins100g      = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g           = "fat_100g"
        case fiber100g         = "fiber_100g"
        case sugars100g        = "sugars_100g"
        case addedSugars100g   = "added-sugars_100g"
        case saturatedFat100g  = "saturated-fat_100g"
        case transFat100g      = "trans-fat_100g"
        case sodium100g        = "sodium_100g"
        case calcium100g       = "calcium_100g"
        case iron100g          = "iron_100g"
        case potassium100g     = "potassium_100g"
        case magnesium100g     = "magnesium_100g"
        case zinc100g          = "zinc_100g"
        case phosphorus100g    = "phosphorus_100g"
        case vitaminA100g      = "vitamin-a_100g"
        case vitaminC100g      = "vitamin-c_100g"
        case vitaminD100g      = "vitamin-d_100g"
        case vitaminE100g      = "vitamin-e_100g"
        case vitaminK100g      = "vitamin-k_100g"
        case vitaminB12100g    = "vitamin-b12_100g"
        case vitaminB6100g     = "vitamin-b6_100g"
        case folate100g        = "folate_100g"
        case omega3100g        = "omega-3-fat_100g"
        case omega6100g        = "omega-6-fat_100g"
    }
}

private struct OFFResponse: Decodable {
    let product: OFFProduct?
    let status: Int
}

enum OFFError: Error, LocalizedError {
    case notFound
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:           return "Product not found in Open Food Facts database."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .decodingError(let e): return "Parsing error: \(e.localizedDescription)"
        }
    }
}

actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    private let baseURL = "https://world.openfoodfacts.org/api/v2/product"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = ["User-Agent": "HealthTracker-iOS/1.0"]
        self.session = URLSession(configuration: config)
    }

    func fetchProduct(barcode: String) async throws -> FoodProduct {
        guard let url = URL(string: "\(baseURL)/\(barcode).json") else {
            throw OFFError.notFound
        }

        let data: Data
        do {
            let (d, _) = try await session.data(from: url)
            data = d
        } catch {
            throw OFFError.networkError(error)
        }

        let response: OFFResponse
        do {
            response = try JSONDecoder().decode(OFFResponse.self, from: data)
        } catch {
            throw OFFError.decodingError(error)
        }

        guard response.status == 1, let off = response.product else {
            throw OFFError.notFound
        }

        return map(off, barcode: barcode)
    }

    // Free-text search, e.g. "wheat thins" — returns candidate matches for the user to pick from
    func search(query: String) async throws -> [FoodProduct] {
        guard var components = URLComponents(string: "https://search.openfoodfacts.org/search") else {
            throw OFFError.notFound
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments,allergens,serving_size")
        ]
        guard let url = components.url else { throw OFFError.notFound }

        let data: Data
        do {
            let (d, _) = try await session.data(from: url)
            data = d
        } catch {
            throw OFFError.networkError(error)
        }

        let response: OFFSearchResponse
        do {
            response = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        } catch {
            throw OFFError.decodingError(error)
        }

        return response.hits
            .compactMap(\.value)
            .filter { $0.productName != nil && !$0.productName!.isEmpty }
            .map(mapHit)
    }

    private func mapHit(_ hit: OFFSearchHit) -> FoodProduct {
        let off = OFFProduct(
            code: hit.code,
            productName: hit.productName,
            brands: hit.brands?.joined(separator: ", "),
            nutriments: hit.nutriments,
            allergens: hit.allergens,
            servingSize: hit.servingSize
        )
        return map(off, barcode: hit.code ?? "")
    }

    private func map(_ off: OFFProduct, barcode: String) -> FoodProduct {
        let n = off.nutriments

        var micronutrients: [String: Double] = [:]

        // Fats
        if let v = n?.saturatedFat100g  { micronutrients["saturated_fat"]  = v }
        if let v = n?.transFat100g      { micronutrients["trans_fat"]       = v }
        if let v = n?.omega3100g        { micronutrients["omega_3"]         = v }
        if let v = n?.omega6100g        { micronutrients["omega_6"]         = v }
        if let v = n?.addedSugars100g   { micronutrients["added_sugar"]     = v }

        // Minerals — OFF returns sodium in kg/100g, rest in g/100g; convert all to mg
        if let v = n?.sodium100g     { micronutrients["sodium"]      = v * 1000 }
        if let v = n?.calcium100g    { micronutrients["calcium"]     = v * 1000 }
        if let v = n?.iron100g       { micronutrients["iron"]        = v * 1000 }
        if let v = n?.potassium100g  { micronutrients["potassium"]   = v * 1000 }
        if let v = n?.magnesium100g  { micronutrients["magnesium"]   = v * 1000 }
        if let v = n?.zinc100g       { micronutrients["zinc"]        = v * 1000 }
        if let v = n?.phosphorus100g { micronutrients["phosphorus"]  = v * 1000 }

        // Vitamins — stored in their natural units (µg or mg per 100g)
        if let v = n?.vitaminA100g   { micronutrients["vitamin_a"]   = v }
        if let v = n?.vitaminC100g   { micronutrients["vitamin_c"]   = v }
        if let v = n?.vitaminD100g   { micronutrients["vitamin_d"]   = v }
        if let v = n?.vitaminE100g   { micronutrients["vitamin_e"]   = v }
        if let v = n?.vitaminK100g   { micronutrients["vitamin_k"]   = v }
        if let v = n?.vitaminB12100g { micronutrients["vitamin_b12"] = v }
        if let v = n?.vitaminB6100g  { micronutrients["vitamin_b6"]  = v }
        if let v = n?.folate100g     { micronutrients["folate"]      = v }

        let allergenList = parseAllergens(off.allergens)

        return FoodProduct(
            name: off.productName ?? "Unknown Product",
            brand: off.brands,
            barcode: barcode,
            servingAmount: 100,
            servingUnit: "g",
            calories: n?.energyKcal100g ?? 0,
            protein: n?.proteins100g ?? 0,
            carbs: n?.carbohydrates100g ?? 0,
            fat: n?.fat100g ?? 0,
            fiber: n?.fiber100g,
            sugar: n?.sugars100g,
            micronutrients: micronutrients,
            allergens: allergenList
        )
    }

    private func parseAllergens(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        // OFF format: "en:gluten,en:milk,en:nuts"
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "en:", with: "") }
            .filter { !$0.isEmpty }
    }
}
