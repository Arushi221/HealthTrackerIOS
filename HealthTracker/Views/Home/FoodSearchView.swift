import SwiftUI

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let mealType: MealType

    @State private var query: String = ""
    @State private var results: [FoodProduct] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProduct: FoodProduct?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView("Searching…")
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                } else if results.isEmpty && !query.isEmpty {
                    Text("No results for \"\(query)\"").foregroundStyle(.secondary)
                }

                ForEach(results) { product in
                    Button {
                        select(product)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .foregroundStyle(.primary)
                            Text(subtitle(for: product))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search foods (e.g. Wheat Thins)")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .navigationTitle("Add to \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(item: $selectedProduct) { product in
                AddFoodToMealView(product: product, presetMealType: mealType, onSave: { dismiss() })
            }
        }
    }

    private func subtitle(for product: FoodProduct) -> String {
        var parts = ["\(Int(product.calories)) kcal per \(Int(product.servingAmount))\(product.servingUnit)"]
        if let brand = product.brand { parts.append(brand) }
        return parts.joined(separator: " · ")
    }

    private func select(_ product: FoodProduct) {
        Task {
            await FoodLookupService.shared.enrichMicronutrients(for: product)
            selectedProduct = product
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }

        isLoading = true
        errorMessage = nil
        do {
            results = try await FoodLookupService.shared.search(query: trimmed)
            if results.isEmpty {
                errorMessage = nil // let the "No results" row show instead
            }
        } catch {
            errorMessage = "Couldn't load results — check your connection and try again."
            results = []
        }
        isLoading = false
    }
}
