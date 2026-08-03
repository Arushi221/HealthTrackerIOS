import SwiftUI
import SwiftData
import UIKit

struct TodayMealsSection: View {
    let logs: [FoodLog]
    let date: Date

    @Environment(\.modelContext) private var context
    @Query private var allLogs: [FoodLog]
    @State private var feedback: String?

    private func logs(for mealType: MealType) -> [FoodLog] {
        logs.filter { $0.meal.mealType == mealType }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Meals")
                        .font(.headline)
                    Spacer()
                    if let feedback {
                        Text(feedback)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                Text("Swipe right to copy yesterday's meals")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(MealType.allCases, id: \.self) { mealType in
                MealTypeSection(mealType: mealType, logs: logs(for: mealType), date: date)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard value.translation.width > 60, abs(value.translation.height) < 50 else { return }
                    copyYesterdaysMeals()
                }
        )
    }

    private func copyYesterdaysMeals() {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { return }
        let yesterdayLogs = allLogs.filter { cal.isDate($0.loggedAt, inSameDayAs: yesterday) }

        guard !yesterdayLogs.isEmpty else {
            showFeedback("No meals logged yesterday")
            return
        }

        for log in yesterdayLogs {
            let newItems = log.meal.items.map { MealItem(product: $0.product, servings: $0.servings) }
            newItems.forEach { context.insert($0) }

            let newMeal = Meal(name: log.meal.name, mealType: log.meal.mealType, items: newItems, date: date)
            context.insert(newMeal)

            let newLog = FoodLog(meal: newMeal, goalId: log.goalId, loggedAt: date)
            context.insert(newLog)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showFeedback("Copied \(yesterdayLogs.count) meal\(yesterdayLogs.count == 1 ? "" : "s") from yesterday")
    }

    private func showFeedback(_ text: String) {
        withAnimation { feedback = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            if feedback == text {
                withAnimation { feedback = nil }
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
                    MealRow(log: log)
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            FoodSearchView(mealType: mealType, date: date)
        }
    }
}

private struct MealRow: View {
    let log: FoodLog
    @Environment(\.modelContext) private var context

    private var meal: Meal { log.meal }

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
            Button {
                context.delete(meal)
                context.delete(log)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
