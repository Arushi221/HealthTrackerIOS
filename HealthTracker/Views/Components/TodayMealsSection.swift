import SwiftUI

struct TodayMealsSection: View {
    let logs: [FoodLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Meals")
                .font(.headline)

            if logs.isEmpty {
                Text("No meals logged yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            } else {
                ForEach(logs) { log in
                    MealRow(meal: log.meal)
                }
            }
        }
    }
}

private struct MealRow: View {
    let meal: Meal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name).font(.subheadline.weight(.medium))
                Text(meal.mealType.rawValue).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(meal.totalCalories)) kcal").font(.subheadline)
                Text("P:\(Int(meal.totalProtein))g  C:\(Int(meal.totalCarbs))g  F:\(Int(meal.totalFat))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
