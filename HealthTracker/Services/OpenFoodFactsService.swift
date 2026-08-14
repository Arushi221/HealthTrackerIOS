import Foundation

struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let allergens: String?
    let servingSize: String?
    let servingQuantity: Double?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case allergens
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
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
    let servingQuantity: Double?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case allergens
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
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

    func fetchProduct(barcode: String) async throws -> (product: FoodProduct, hasServingData: Bool) {
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
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments,allergens,serving_size,serving_quantity")
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
            .map { mapHit($0).product }
    }

    private func mapHit(_ hit: OFFSearchHit) -> (product: FoodProduct, hasServingData: Bool) {
        let off = OFFProduct(
            code: hit.code,
            productName: hit.productName,
            brands: hit.brands?.joined(separator: ", "),
            nutriments: hit.nutriments,
            allergens: hit.allergens,
            servingSize: hit.servingSize,
            servingQuantity: hit.servingQuantity
        )
        return map(off, barcode: hit.code ?? "")
    }

    private func map(_ off: OFFProduct, barcode: String) -> (product: FoodProduct, hasServingData: Bool) {
        let n = off.nutriments

        // OFF's own nutriment fields are always "per 100g" regardless of the
        // product's actual serving size — scale everything by the real
        // serving so "1 serving" in the app matches what's on the label,
        // not always 100g. When OFF genuinely has no serving data (common —
        // e.g. its search index never carries it, and plenty of products
        // lack it even on the full record), fall back to 100g but flag it
        // so the caller can try a second source instead of trusting it.
        let realServingGrams = off.servingQuantity ?? Self.parseGrams(from: off.servingSize)
        let servingGrams = realServingGrams ?? 100
        let scale = servingGrams / 100.0

        var micronutrients: [String: Double] = [:]

        // Fats
        if let v = n?.saturatedFat100g  { micronutrients["saturated_fat"]  = v * scale }
        if let v = n?.transFat100g      { micronutrients["trans_fat"]       = v * scale }
        if let v = n?.omega3100g        { micronutrients["omega_3"]         = v * scale }
        if let v = n?.omega6100g        { micronutrients["omega_6"]         = v * scale }
        if let v = n?.addedSugars100g   { micronutrients["added_sugar"]     = v * scale }

        // Minerals — OFF returns sodium in kg/100g, rest in g/100g; convert all to mg, then scale
        if let v = n?.sodium100g     { micronutrients["sodium"]      = v * 1000 * scale }
        if let v = n?.calcium100g    { micronutrients["calcium"]     = v * 1000 * scale }
        if let v = n?.iron100g       { micronutrients["iron"]        = v * 1000 * scale }
        if let v = n?.potassium100g  { micronutrients["potassium"]   = v * 1000 * scale }
        if let v = n?.magnesium100g  { micronutrients["magnesium"]   = v * 1000 * scale }
        if let v = n?.zinc100g       { micronutrients["zinc"]        = v * 1000 * scale }
        if let v = n?.phosphorus100g { micronutrients["phosphorus"]  = v * 1000 * scale }

        // Vitamins — stored in their natural units (µg or mg), scaled to the serving
        if let v = n?.vitaminA100g   { micronutrients["vitamin_a"]   = v * scale }
        if let v = n?.vitaminC100g   { micronutrients["vitamin_c"]   = v * scale }
        if let v = n?.vitaminD100g   { micronutrients["vitamin_d"]   = v * scale }
        if let v = n?.vitaminE100g   { micronutrients["vitamin_e"]   = v * scale }
        if let v = n?.vitaminK100g   { micronutrients["vitamin_k"]   = v * scale }
        if let v = n?.vitaminB12100g { micronutrients["vitamin_b12"] = v * scale }
        if let v = n?.vitaminB6100g  { micronutrients["vitamin_b6"]  = v * scale }
        if let v = n?.folate100g     { micronutrients["folate"]      = v * scale }

        let allergenList = parseAllergens(off.allergens)

        let product = FoodProduct(
            name: off.productName ?? "Unknown Product",
            brand: off.brands,
            barcode: barcode,
            servingAmount: servingGrams,
            servingUnit: "g",
            calories: (n?.energyKcal100g ?? 0) * scale,
            protein: (n?.proteins100g ?? 0) * scale,
            carbs: (n?.carbohydrates100g ?? 0) * scale,
            fat: (n?.fat100g ?? 0) * scale,
            fiber: n?.fiber100g.map { $0 * scale },
            sugar: n?.sugars100g.map { $0 * scale },
            micronutrients: micronutrients,
            allergens: allergenList
        )
        return (product, realServingGrams != nil)
    }

    // Fallback for when OFF doesn't provide a parsed serving_quantity but the
    // free-text serving_size string has a gram amount in it, e.g. "30 g" or
    // "2 tbsp (32g)" (in which case the parenthetical, if present, wins since
    // it's usually the gram equivalent of a non-gram primary unit).
    private static func parseGrams(from servingSize: String?) -> Double? {
        guard let text = servingSize else { return nil }
        let pattern = /(\d+(?:\.\d+)?)\s*g\b/.ignoresCase()
        guard let match = text.matches(of: pattern).last else { return nil }
        return Double(match.1)
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
