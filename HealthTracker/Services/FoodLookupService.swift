import Foundation

actor FoodLookupService {
    static let shared = FoodLookupService()
    private init() {}

    // Scans barcode via OFF, then enriches micronutrients from USDA for any gaps
    func lookup(barcode: String) async throws -> FoodProduct {
        let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)

        let missingKeys: Set<String> = [
            "omega_3", "omega_6", "vitamin_b12", "vitamin_d",
            "iron", "calcium", "magnesium", "zinc", "folate"
        ]
        let hasMissing = missingKeys.contains { product.micronutrients[$0] == nil }

        if hasMissing {
            let usdaData = await USDAService.shared.fetchMicronutrients(for: product.name)
            for (key, value) in usdaData where product.micronutrients[key] == nil {
                product.micronutrients[key] = value
            }
        }

        return product
    }
}
