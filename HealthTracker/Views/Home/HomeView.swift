import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]
    @Query(filter: #Predicate<FoodCategoryGoal> { $0.isActive }) private var foodCategoryGoals: [FoodCategoryGoal]
    @Query private var logs: [FoodLog]
    @State private var exerciseCalories: Double = 0
    @State private var selectedDate: Date = Date()
    @Environment(\.scenePhase) private var scenePhase

    private var trackedCategories: [FoodCategory] {
        FoodCategoryCatalog.all.filter { category in
            foodCategoryGoals.contains { $0.categoryKey == category.key }
        }
    }

    private var dayLogs: [FoodLog] {
        let cal = Calendar.current
        return logs.filter { cal.isDate($0.loggedAt, inSameDayAs: selectedDate) }
    }

    private var consumed: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let meals = dayLogs.map(\.meal)
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
                    DateNavigationHeader(date: $selectedDate)

                    if let goal = goals.first(where: { $0.period == .day }) {
                        MacroProgressCard(goal: goal, consumed: consumed, exerciseCalories: exerciseCalories)
                    } else {
                        NoGoalBanner()
                    }

                    TodayMealsSection(logs: dayLogs, date: selectedDate)

                    ForEach(trackedCategories) { category in
                        FoodCategoryCard(category: category, logs: logs)
                    }
                }
                .padding()
            }
            .navigationTitle("Diary")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: BarcodeScannerView(date: selectedDate)) {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .task(id: selectedDate) {
                await loadExerciseCalories()
            }
            // A workout logged in the Fitness/Health app or via Apple Watch
            // while HealthTracker is backgrounded won't trigger the .task
            // above (selectedDate hasn't changed) — refetch whenever the app
            // comes back to the foreground so calories earned from it show
            // up without the user having to flip dates to force a reload.
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await loadExerciseCalories() }
                }
            }
            .refreshable {
                await loadExerciseCalories()
            }
        }
    }

    private func loadExerciseCalories() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            exerciseCalories = try await HealthKitService.shared.activeEnergyBurned(on: selectedDate)
        } catch {
            exerciseCalories = 0
        }
    }
}

private struct DateNavigationHeader: View {
    @Binding var date: Date
    @State private var showingPicker = false

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        HStack {
            Button {
                changeDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Button {
                showingPicker = true
            } label: {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button {
                changeDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("Jump to Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingPicker = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    private func changeDay(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: offset, to: date) {
            date = newDate
        }
    }
}
