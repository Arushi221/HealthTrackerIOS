import SwiftUI

struct FoodCategoryGoalCard: View {
    let goal: FoodCategoryGoal
    let category: FoodCategory
    let logs: [FoodLog]
    let keywords: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(category.displayName)
                .font(.headline)

            if keywords.isEmpty {
                Text("Refresh this category on the Diary tab to start counting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(GoalPeriod.allCases, id: \.self) { period in
                let progress = goal.progress(for: period, logs: logs, keywords: keywords)
                CountBar(label: period.rawValue, value: progress.count, target: progress.target)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
