import SwiftUI

struct MacroProgressCard: View {
    let goal: Goal
    let consumed: (calories: Double, protein: Double, carbs: Double, fat: Double)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Goals")
                .font(.headline)

            MacroBar(
                label: "Calories",
                value: consumed.calories,
                target: goal.targetCalories,
                color: .orange,
                unit: "kcal"
            )
            MacroBar(
                label: "Protein",
                value: consumed.protein,
                target: goal.targetProtein,
                color: .blue,
                unit: "g"
            )
            MacroBar(
                label: "Carbs",
                value: consumed.carbs,
                target: goal.targetCarbs,
                color: .green,
                unit: "g"
            )
            MacroBar(
                label: "Fat",
                value: consumed.fat,
                target: goal.targetFat,
                color: .yellow,
                unit: "g"
            )
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MacroBar: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color
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
                .tint(progress >= 1.0 ? .red : color)
        }
    }
}
