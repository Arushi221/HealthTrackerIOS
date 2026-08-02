import SwiftUI

struct FoodCategoryCard: View {
    let category: FoodCategory
    let logs: [FoodLog]

    @State private var keywords: [String]
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(category: FoodCategory, logs: [FoodLog]) {
        self.category = category
        self.logs = logs
        _keywords = State(initialValue: FoodCategoryCache.foods(for: category))
    }

    private var thisWeekLogs: [FoodLog] {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        return logs.filter { $0.loggedAt >= weekAgo }
    }

    private var matches: [FoodLog] {
        thisWeekLogs.matching(keywords: keywords)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.displayName).font(.headline)
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)
            }

            if keywords.isEmpty {
                Text("Tap refresh to load a food list from Claude.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(matches.count) matching \(matches.count == 1 ? "food" : "foods") logged this week")
                    .font(.subheadline)
                if !matches.isEmpty {
                    Text(matches.map { $0.meal.name }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            if FoodCategoryCache.needsRefresh(for: category) { await refresh() }
        }
    }

    private func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let foods = try await FoodCategoryService.shared.fetchFoods(for: category)
            FoodCategoryCache.save(foods, for: category)
            keywords = foods
        } catch {
            errorMessage = (error as? AnthropicServiceError)?.errorDescription ?? "Couldn't load foods."
        }
        isLoading = false
    }
}
