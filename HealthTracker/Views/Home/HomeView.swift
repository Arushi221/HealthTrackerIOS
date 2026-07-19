import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]
    @Query private var logs: [FoodLog]

    private var todayLogs: [FoodLog] {
        let cal = Calendar.current
        return logs.filter { cal.isDateInToday($0.loggedAt) }
    }

    private var consumed: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let meals = todayLogs.map(\.meal)
        return (
            meals.reduce(0) { $0 + $1.totalCalories },
            meals.reduce(0) { $0 + $1.totalProtein },
            meals.reduce(0) { $0 + $1.totalCarbs },
            meals.reduce(0) { $0 + $1.totalFat }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let goal = goals.first(where: { $0.period == .day }) {
                        MacroProgressCard(goal: goal, consumed: consumed)
                    } else {
                        NoGoalBanner()
                    }

                    TodayMealsSection(logs: todayLogs)
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: BarcodeScannerView()) {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
        }
    }
}
