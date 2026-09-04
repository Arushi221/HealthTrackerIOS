import SwiftUI

struct MacroProgressCard: View {
    let goal: Goal
    let consumed: (calories: Double, protein: Double, carbs: Double, fat: Double)
    var exerciseCalories: Double = 0

    private var calorieTarget: Double { goal.targetCalories + exerciseCalories }

    // Split of the goal's macro calories across protein/carbs/fat, used to
    // hand out workout-earned calories in the same ratio as the rest of the
    // goal rather than picking one macro arbitrarily.
    private var macroCalorieSplit: (protein: Double, carbs: Double, fat: Double) {
        let proteinCal = goal.targetProtein * 4
        let carbsCal = goal.targetCarbs * 4
        let fatCal = goal.targetFat * 9
        let total = proteinCal + carbsCal + fatCal
        guard total > 0 else { return (1.0 / 3, 1.0 / 3, 1.0 / 3) }
        return (proteinCal / total, carbsCal / total, fatCal / total)
    }

    private var proteinTarget: Double { goal.targetProtein + (exerciseCalories * macroCalorieSplit.protein) / 4 }
    private var carbsTarget: Double { goal.targetCarbs + (exerciseCalories * macroCalorieSplit.carbs) / 4 }
    private var fatTarget: Double { goal.targetFat + (exerciseCalories * macroCalorieSplit.fat) / 9 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Goals")
                .font(.headline)

            MacroBar(
                label: "Calories",
                value: consumed.calories,
                target: calorieTarget,
                color: .orange,
                unit: "kcal"
            )
            if exerciseCalories > 0 {
                Text("+\(Int(exerciseCalories)) kcal earned from workouts — macro targets below include your share of it")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            MacroBar(
                label: "Protein",
                value: consumed.protein,
                target: proteinTarget,
                color: .blue,
                unit: "g"
            )
            MacroBar(
                label: "Carbs",
                value: consumed.carbs,
                target: carbsTarget,
                color: .green,
                unit: "g"
            )
            MacroBar(
                label: "Fat",
                value: consumed.fat,
                target: fatTarget,
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
