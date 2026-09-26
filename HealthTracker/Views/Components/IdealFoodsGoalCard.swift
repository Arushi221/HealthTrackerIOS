import SwiftUI
import SwiftData

struct IdealFoodsGoalCard: View {
    let goal: IdealFoodGoal
    let logs: [FoodLog]

    @State private var isChecking = false
    @State private var errorMessage: String?

    private var lastCheckedLabel: String? {
        guard let lastCheckedAt = goal.lastCheckedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        return "Checked \(formatter.localizedString(for: lastCheckedAt, relativeTo: Date()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Ideal Foods").font(.headline)
                Spacer()
                Button {
                    Task { await checkMatches() }
                } label: {
                    if isChecking {
                        ProgressView()
                    } else {
                        Label("Check Matches", systemImage: "sparkles")
                            .font(.caption)
                    }
                }
                .disabled(isChecking || goal.foods.isEmpty)
            }

            if goal.foods.isEmpty {
                Text("Add foods from Edit, then tap Check Matches to see how you're doing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(GoalPeriod.allCases, id: \.self) { period in
                    let progress = goal.progress(for: period)
                    CountBar(label: period.rawValue, value: progress.count, target: progress.target)
                }

                if let lastCheckedLabel {
                    Text(lastCheckedLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not checked yet.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func checkMatches() async {
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }
        do {
            let matches = try await IdealFoodMatchService.shared.findMatches(foods: goal.foods, logs: logs)
            goal.matches = matches
            goal.lastCheckedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CountBar: View {
    let label: String
    let value: Int
    let target: Int

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(value) / Double(target), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(value) / \(target) foods")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(progress >= 1.0 ? Color.green : Color.purple)
        }
    }
}
