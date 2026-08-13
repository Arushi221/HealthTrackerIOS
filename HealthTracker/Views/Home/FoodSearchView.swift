import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodProduct.dateAdded, order: .reverse) private var allProducts: [FoodProduct]
    let mealType: MealType
    let date: Date

    @State private var query: String = ""
    @State private var results: [FoodProduct] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProduct: FoodProduct?
    @State private var searchTask: Task<Void, Never>?

    // Foods you've logged before that match what you're typing — instant,
    // no network round trip, and de-duplicated (a food logged 5 times over
    // 5 days creates 5 FoodProduct rows, but should only suggest once).
    private var previouslyLogged: [FoodProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var seenNames = Set<String>()
        var matches: [FoodProduct] = []
        for product in allProducts {
            guard product.name.localizedCaseInsensitiveContains(trimmed) else { continue }
            let key = product.name.lowercased()
            guard !seenNames.contains(key) else { continue }
            seenNames.insert(key)
            matches.append(product)
            if matches.count == 10 { break }
        }
        return matches
    }

    var body: some View {
        NavigationStack {
            List {
                if !previouslyLogged.isEmpty {
                    Section("Previously Logged") {
                        ForEach(previouslyLogged) { product in
                            Button {
                                select(product)
                            } label: {
                                ProductRow(product: product)
                            }
                        }
                    }
                }

                if isLoading {
                    ProgressView("Searching…")
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                } else if results.isEmpty && !query.isEmpty && previouslyLogged.isEmpty {
                    Text("No results for \"\(query)\"").foregroundStyle(.secondary)
                }

                if !results.isEmpty {
                    Section(previouslyLogged.isEmpty ? "" : "Search Results") {
                        ForEach(results) { product in
                            Button {
                                select(product)
                            } label: {
                                ProductRow(product: product)
                            }
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

private struct ProductRow: View {
    let product: FoodProduct

    private var caloriesLine: String {
        var parts = ["\(Int(product.calories)) kcal per \(Int(product.servingAmount))\(product.servingUnit)"]
        if let brand = product.brand { parts.append(brand) }
        return parts.joined(separator: " · ")
    }

    private var macrosLine: String {
        "P: \(Int(product.protein))g  C: \(Int(product.carbs))g  F: \(Int(product.fat))g"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(product.name)
                .foregroundStyle(.primary)
            Text(caloriesLine)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(macrosLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
