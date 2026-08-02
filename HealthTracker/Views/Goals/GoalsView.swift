import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]
    @Query(filter: #Predicate<NutrientGoal> { $0.isActive }) private var nutrientGoals: [NutrientGoal]
    @Query(filter: #Predicate<FoodCategoryGoal> { $0.isActive }) private var foodCategoryGoals: [FoodCategoryGoal]
    @Query private var logs: [FoodLog]
    @State private var showingAddGoal = false
    @State private var showingAddNutrientGoal = false
    @State private var editingGoal: Goal?
    @State private var editingNutrientGoal: NutrientGoal?
    @State private var addingCategoryGoal: FoodCategory?
    @State private var editingCategoryGoal: FoodCategoryGoal?

    var body: some View {
        NavigationStack {
            List {
                Section("Macro Targets") {
                    ForEach(GoalPeriod.allCases, id: \.self) { period in
                        if let goal = goals.first(where: { $0.period == period }) {
                            GoalRow(goal: goal)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        context.delete(goal)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        editingGoal = goal
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
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
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(goal)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingNutrientGoal = goal
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }

                    if nutrientGoals.count < NutrientCatalog.all.count {
                        Button("Add Nutrient Goal") {
                            showingAddNutrientGoal = true
                        }
                        .foregroundStyle(.blue)
                    }
                }

                Section("Food Categories") {
                    ForEach(FoodCategoryCatalog.all) { category in
                        if let goal = foodCategoryGoals.first(where: { $0.categoryKey == category.key }) {
                            FoodCategoryGoalCard(
                                goal: goal,
                                category: category,
                                logs: logs,
                                keywords: FoodCategoryCache.foods(for: category)
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(goal)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingCategoryGoal = goal
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        } else {
                            Button("Set \(category.displayName) Goal") {
                                addingCategoryGoal = category
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                }

                Section("Health") {
                    NavigationLink("Lab Results") {
                        LabResultsView()
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
            .sheet(item: $editingGoal) { goal in
                AddGoalView(existingGoal: goal)
            }
            .sheet(item: $editingNutrientGoal) { goal in
                EditNutrientGoalView(goal: goal)
            }
            .sheet(item: $addingCategoryGoal) { category in
                AddFoodCategoryGoalView(category: category)
            }
            .sheet(item: $editingCategoryGoal) { goal in
                if let category = FoodCategoryCatalog.all.first(where: { $0.key == goal.categoryKey }) {
                    AddFoodCategoryGoalView(category: category, existingGoal: goal)
                }
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
