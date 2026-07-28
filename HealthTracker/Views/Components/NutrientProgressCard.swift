import SwiftUI

struct NutrientProgressCard: View {
    let goal: NutrientGoal
    let logs: [FoodLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(goal.displayName)
                .font(.headline)

            ForEach(GoalPeriod.allCases, id: \.self) { period in
                let progress = goal.progress(for: period, logs: logs)
                NutrientBar(
                    label: period.rawValue,
                    value: progress.consumed,
                    target: progress.target,
                    unit: goal.unit
                )
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct NutrientBar: View {
    let label: String
    let value: Double
    let target: Double
    let unit: String

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(value / target, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(value)) / \(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(progress >= 1.0 ? .red : .purple)
        }
    }
}
