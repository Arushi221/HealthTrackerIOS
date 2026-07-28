import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]
    @Query(filter: #Predicate<NutrientGoal> { $0.isActive }) private var nutrientGoals: [NutrientGoal]
    @Query private var logs: [FoodLog]
    @State private var showingAddGoal = false
    @State private var showingAddNutrientGoal = false

    var body: some View {
        NavigationStack {
            List {
                Section("Macro Targets") {
                    ForEach(GoalPeriod.allCases, id: \.self) { period in
                        if let goal = goals.first(where: { $0.period == period }) {
                            GoalRow(goal: goal)
                        } else {
                            Button("Set \(period.rawValue) Goal") {
                                showingAddGoal = true
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                }

                Section("Micronutrients") {
                    ForEach(nutrientGoals) { goal in
                        NutrientProgressCard(goal: goal, logs: logs)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(nutrientGoals[index])
                        }
                    }

                    if nutrientGoals.count < NutrientCatalog.all.count {
                        Button("Add Nutrient Goal") {
                            showingAddNutrientGoal = true
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddGoal = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView()
            }
            .sheet(isPresented: $showingAddNutrientGoal) {
                AddNutrientGoalView()
            }
        }
    }
}

private struct GoalRow: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(goal.period.rawValue).font(.headline)
            HStack(spacing: 16) {
                MacroLabel(name: "Cal", value: goal.targetCalories, unit: "kcal")
                MacroLabel(name: "Protein", value: goal.targetProtein, unit: "g")
                MacroLabel(name: "Carbs", value: goal.targetCarbs, unit: "g")
                MacroLabel(name: "Fat", value: goal.targetFat, unit: "g")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MacroLabel: View {
    let name: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value))\(unit)").font(.subheadline.weight(.semibold))
            Text(name).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
