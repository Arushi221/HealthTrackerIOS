import SwiftUI

struct TodayMealsSection: View {
    let logs: [FoodLog]
    let date: Date

    private func logs(for mealType: MealType) -> [FoodLog] {
        logs.filter { $0.meal.mealType == mealType }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Meals")
                .font(.headline)

            ForEach(MealType.allCases, id: \.self) { mealType in
                MealTypeSection(mealType: mealType, logs: logs(for: mealType), date: date)
            }
        }
    }
}

private struct MealTypeSection: View {
    let mealType: MealType
    let logs: [FoodLog]
    let date: Date

    @State private var showingSearch = false

    private var totalCalories: Double {
        logs.reduce(0) { $0 + $1.meal.totalCalories }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mealType.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !logs.isEmpty {
                    Text("\(Int(totalCalories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }

            if logs.isEmpty {
                Text("No items logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(logs) { log in
                    MealRow(meal: log.meal)
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            FoodSearchView(mealType: mealType, date: date)
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
