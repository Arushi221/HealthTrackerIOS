import Foundation

actor FoodLookupService {
    static let shared = FoodLookupService()
    private init() {}

    // Scans barcode via OFF, then enriches micronutrients from USDA for any gaps
    func lookup(barcode: String) async throws -> FoodProduct {
        let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
        await enrichMicronutrients(for: product)
        return product
    }

    // Free-text search, e.g. "wheat thins" — candidates are left un-enriched until picked,
    // so a 20-result search doesn't trigger 20 USDA lookups
    func search(query: String) async throws -> [FoodProduct] {
        try await OpenFoodFactsService.shared.search(query: query)
    }

    func enrichMicronutrients(for product: FoodProduct) async {
        let missingKeys: Set<String> = [
            "omega_3", "omega_6", "vitamin_b12", "vitamin_d",
            "iron", "calcium", "magnesium", "zinc", "folate"
        ]
        let hasMissing = missingKeys.contains { product.micronutrients[$0] == nil }
        guard hasMissing else { return }

        // USDA values are per 100g — scale to the product's actual serving
        // size so they line up with the rest of its (already per-serving)
        // nutrition data instead of always assuming a 100g serving.
        let scale = product.servingAmount / 100.0
        let usdaData = await USDAService.shared.fetchMicronutrients(for: product.name)
        for (key, value) in usdaData where product.micronutrients[key] == nil {
            product.micronutrients[key] = value * scale
        }
    }
}
