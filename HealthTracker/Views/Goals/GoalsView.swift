import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]
    @State private var showingAddGoal = false

    var body: some View {
        NavigationStack {
            List {
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
