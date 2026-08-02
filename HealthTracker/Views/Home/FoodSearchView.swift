import SwiftUI

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let mealType: MealType
    let date: Date

    @State private var query: String = ""
    @State private var results: [FoodProduct] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProduct: FoodProduct?
    @State private var searchTask: Task<Void, Never>?

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
                            Text(caloriesLine(for: product))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(macrosLine(for: product))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search foods (e.g. Wheat Thins)")
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    results = []
                    isLoading = false
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !Task.isCancelled else { return }
                    await search()
                }
            }
            .navigationTitle("Add to \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(item: $selectedProduct) { product in
                AddFoodToMealView(product: product, presetMealType: mealType, date: date, onSave: { dismiss() })
            }
        }
    }

    private func caloriesLine(for product: FoodProduct) -> String {
        var parts = ["\(Int(product.calories)) kcal per \(Int(product.servingAmount))\(product.servingUnit)"]
        if let brand = product.brand { parts.append(brand) }
        return parts.joined(separator: " · ")
    }

    private func macrosLine(for product: FoodProduct) -> String {
        "P: \(Int(product.protein))g  C: \(Int(product.carbs))g  F: \(Int(product.fat))g"
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
            let fetched = try await FoodLookupService.shared.search(query: trimmed)
            // Ignore a slow response that finishes after a newer search already started
            guard trimmed == query.trimmingCharacters(in: .whitespaces) else { return }
            results = fetched
        } catch {
            guard trimmed == query.trimmingCharacters(in: .whitespaces) else { return }
            errorMessage = "Couldn't load results — check your connection and try again."
            results = []
        }
        isLoading = false
    }
}
