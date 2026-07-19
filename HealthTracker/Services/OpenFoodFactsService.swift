import Foundation

struct OFFProduct: Decodable {
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let allergens: String?
    let servingSize: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
        case allergens
        case servingSize = "serving_size"
    }
}

struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let sodium100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g    = "energy-kcal_100g"
        case proteins100g      = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g           = "fat_100g"
        case fiber100g         = "fiber_100g"
        case sugars100g        = "sugars_100g"
        case sodium100g        = "sodium_100g"
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

    private func map(_ off: OFFProduct, barcode: String) -> FoodProduct {
        let n = off.nutriments

        var micronutrients: [String: Double] = [:]
        if let sodium = n?.sodium100g { micronutrients["sodium"] = sodium * 1000 }  // convert kg→mg

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
