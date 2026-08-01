import SwiftUI

struct BrainFoodCard: View {
    let logs: [FoodLog]

    @State private var keywords: [String] = BrainFoodCache.foods
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var thisWeekLogs: [FoodLog] {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        return logs.filter { $0.loggedAt >= weekAgo }
    }

    private var matches: [FoodLog] {
        thisWeekLogs.brainHealthyMatches(against: keywords)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Brain Health").font(.headline)
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
                Text("Tap refresh to load a brain-healthy food list from Claude.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(matches.count) brain-healthy \(matches.count == 1 ? "food" : "foods") logged this week")
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
            if BrainFoodCache.needsRefresh { await refresh() }
        }
    }

    private func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let foods = try await BrainFoodService.shared.fetchBrainHealthyFoods()
            BrainFoodCache.save(foods)
            keywords = foods
        } catch {
            errorMessage = (error as? BrainFoodError)?.errorDescription ?? "Couldn't load brain-healthy foods."
        }
        isLoading = false
    }
}
