import SwiftUI
import SwiftData

struct MealPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]
    @Query private var labResults: [LabResult]
    @Query private var profiles: [UserProfile]

    @State private var weekPlan: [SuggestedMeal] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loggedMealIDs: Set<String> = []

    @State private var selectedMealForRecipe: SuggestedMeal?
    @State private var showingShoppingList = false
    @State private var shoppingList: ShoppingList?
    @State private var isGeneratingShoppingList = false
    @State private var shoppingListError: String?

    private var goal: Goal? { goals.first(where: { $0.period == .day }) }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Group {
                if let goal {
                    content(for: goal)
                } else {
                    placeholder
                }
            }
            .navigationTitle("Meal Plan")
            .toolbar {
                if goal != nil, !weekPlan.isEmpty {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            generateShoppingListAction()
                        } label: {
                            Image(systemName: "cart")
                        }
                        Button {
                            Task { await generate() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .sheet(item: $selectedMealForRecipe) { meal in
                RecipeSheetView(meal: meal, allergensToAvoid: goal?.excludedAllergens ?? [])
            }
            .sheet(isPresented: $showingShoppingList) {
                ShoppingListSheetView(
                    shoppingList: shoppingList,
                    isLoading: isGeneratingShoppingList,
                    errorMessage: shoppingListError,
                    onRetry: generateShoppingListAction
                )
            }
        }
    }

    @ViewBuilder
    private func content(for goal: Goal) -> some View {
        if isLoading {
            ProgressView("Generating your weekly meal plan…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Try Again") { Task { await generate() } }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if weekPlan.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Get a week of meal suggestions tailored to your goals, lab results, allergens, and budget.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Generate Weekly Meal Plan") { Task { await generate() } }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if !goal.excludedAllergens.isEmpty {
                    Section {
                        Label("Avoiding: \(goal.excludedAllergens.joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(0..<7, id: \.self) { day in
                    let dayMeals = weekPlan.filter { $0.day == day }
                    if !dayMeals.isEmpty {
                        Section(dayLabel(for: day)) {
                            ForEach(MealType.allCases, id: \.self) { mealType in
                                if let meal = dayMeals.first(where: { $0.mealType == mealType.rawValue }) {
                                    SuggestedMealRow(
                                        meal: meal,
                                        isLogged: loggedMealIDs.contains(meal.id),
                                        onTapRecipe: { selectedMealForRecipe = meal },
                                        onLog: { logMeal(meal, goal: goal) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Meal Planning")
                .font(.headline)
            Text("Set your daily goals first, then meal suggestions will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayLabel(for day: Int) -> String {
        let date = dateForDay(day)
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func dateForDay(_ day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private func generate() async {
        guard let goal else { return }
        isLoading = true
        errorMessage = nil
        shoppingList = nil
        loggedMealIDs = []
        do {
            weekPlan = try await MealPlanService.shared.generateWeeklyPlan(goal: goal, labResults: labResults, profile: profile)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func generateShoppingListAction() {
        guard shoppingList == nil else {
            showingShoppingList = true
            return
        }
        guard !weekPlan.isEmpty else { return }

        isGeneratingShoppingList = true
        shoppingListError = nil
        showingShoppingList = true

        Task {
            do {
                shoppingList = try await MealPlanService.shared.generateShoppingList(for: weekPlan, profile: profile)
            } catch {
                shoppingListError = error.localizedDescription
            }
            isGeneratingShoppingList = false
        }
    }

    private func logMeal(_ meal: SuggestedMeal, goal: Goal) {
        guard let mealType = MealType(rawValue: meal.mealType) else { return }
        let date = dateForDay(meal.day)

        let product = FoodProduct(
            name: meal.name,
            servingAmount: 1,
            servingUnit: "meal",
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat
        )
        context.insert(product)

        let item = MealItem(product: product, servings: 1)
        context.insert(item)

        let newMeal = Meal(name: meal.name, mealType: mealType, items: [item], date: date)
        context.insert(newMeal)

        let log = FoodLog(meal: newMeal, goalId: goal.id, loggedAt: date)
        context.insert(log)

        loggedMealIDs.insert(meal.id)
    }
}

private struct SuggestedMealRow: View {
    let meal: SuggestedMeal
    let isLogged: Bool
    let onTapRecipe: () -> Void
    let onLog: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.mealType).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(meal.name).font(.subheadline.weight(.medium))
                Text(meal.description).font(.caption).foregroundStyle(.secondary)
                Text("\(Int(meal.calories)) kcal · P:\(Int(meal.protein))g C:\(Int(meal.carbs))g F:\(Int(meal.fat))g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 10) {
                Button(action: onLog) {
                    Image(systemName: isLogged ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(isLogged ? .green : .accentColor)
                }
                .disabled(isLogged)
                Button(action: onTapRecipe) {
                    Image(systemName: "book")
                }
            }
            .buttonStyle(.borderless)
            .font(.title3)
        }
        .padding(.vertical, 4)
    }
}

private struct RecipeSheetView: View {
    let meal: SuggestedMeal
    let allergensToAvoid: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var recipe: Recipe?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading recipe…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again") { Task { await loadRecipe() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let recipe {
                    List {
                        Section("Ingredients") {
                            ForEach(recipe.ingredients, id: \.self) { Text($0) }
                        }
                        Section("Instructions") {
                            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                                Text("\(index + 1). \(step)")
                            }
                        }
                        if let cost = recipe.estimatedCost {
                            Section {
                                Text("Estimated cost: $\(cost, specifier: "%.2f")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadRecipe()
            }
        }
    }

    private func loadRecipe() async {
        isLoading = true
        errorMessage = nil
        do {
            recipe = try await MealPlanService.shared.generateRecipe(for: meal, allergensToAvoid: allergensToAvoid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ShoppingListSheetView: View {
    let shoppingList: ShoppingList?
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Building shopping list…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again", action: onRetry)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let shoppingList {
                    List {
                        Section {
                            HStack {
                                Text("Estimated Total")
                                Spacer()
                                Text("$\(shoppingList.estimatedTotalCost, specifier: "%.2f")")
                                    .foregroundStyle(shoppingList.withinBudget ? .green : .red)
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        ForEach(shoppingList.byStore, id: \.store) { entry in
                            Section(entry.store) {
                                ForEach(Dictionary(grouping: entry.items, by: \.department).keys.sorted(), id: \.self) { department in
                                    DisclosureGroup(department) {
                                        ForEach(entry.items.filter { $0.department == department }) { item in
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(item.name).font(.subheadline)
                                                    Text(item.quantity).font(.caption).foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                Text("$\(item.estimatedCost, specifier: "%.2f")")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("No shopping list yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
