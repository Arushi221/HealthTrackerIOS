import SwiftUI
import SwiftData
import UIKit

struct MealPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]
    @Query private var labResults: [LabResult]
    @Query private var profiles: [UserProfile]
    @Query private var savedPlans: [SavedMealPlan]

    @State private var weekPlan: [SuggestedMeal] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loggedMealIDs: Set<String> = []
    @State private var mealServings: [String: Double] = [:]
    @State private var customInstructions: String = ""
    @State private var didSave = false

    @State private var selectedMealForRecipe: SuggestedMeal?
    @State private var showingShoppingList = false
    @State private var shoppingList: ShoppingList?
    @State private var isGeneratingShoppingList = false
    @State private var shoppingListError: String?

    private var goal: Goal? { goals.first(where: { $0.period == .day }) }
    private var profile: UserProfile? { profiles.first }
    private var savedPlan: SavedMealPlan? { savedPlans.first }

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
            .safeAreaInset(edge: .top) {
                if goal != nil {
                    CustomizationBar(text: $customInstructions, onSubmit: { Task { await generate() } })
                }
            }
            .toolbar {
                if goal != nil, !weekPlan.isEmpty {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            savePlan()
                        } label: {
                            Image(systemName: didSave ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .foregroundStyle(didSave ? .green : .accentColor)
                        }
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
            .onAppear(perform: loadSavedPlanIfNeeded)
            .sheet(item: $selectedMealForRecipe) { meal in
                RecipeSheetView(meal: meal, servings: mealServings[meal.id] ?? 1, allergensToAvoid: goal?.excludedAllergens ?? [])
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
                                        servings: mealServings[meal.id] ?? 1,
                                        isLogged: loggedMealIDs.contains(meal.id),
                                        onTapRecipe: { selectedMealForRecipe = meal },
                                        onLog: { logMeal(meal, goal: goal) },
                                        onServingsChange: { updateServings(for: meal, to: $0) }
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

    // Restore a previously saved plan on first appearance so it survives
    // app restarts — only when nothing is already loaded, so it doesn't
    // clobber an in-progress regeneration if the view re-appears.
    private func loadSavedPlanIfNeeded() {
        guard weekPlan.isEmpty, let savedPlan else { return }
        weekPlan = savedPlan.meals
        mealServings = savedPlan.mealServings
        didSave = true
    }

    private func savePlan() {
        guard !weekPlan.isEmpty else { return }
        if let savedPlan {
            savedPlan.meals = weekPlan
            savedPlan.mealServings = mealServings
            savedPlan.savedAt = Date()
        } else {
            context.insert(SavedMealPlan(meals: weekPlan, mealServings: mealServings))
        }
        withAnimation { didSave = true }
    }

    private func generate() async {
        guard let goal else { return }
        isLoading = true
        errorMessage = nil
        shoppingList = nil
        loggedMealIDs = []
        mealServings = [:]
        didSave = false
        do {
            weekPlan = try await MealPlanService.shared.generateWeeklyPlan(goal: goal, labResults: labResults, profile: profile, customInstructions: customInstructions)
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
                shoppingList = try await MealPlanService.shared.generateShoppingList(for: weekPlan, servings: mealServings, profile: profile)
            } catch {
                shoppingListError = error.localizedDescription
            }
            isGeneratingShoppingList = false
        }
    }

    // Servings affect ingredient quantities, so an already-generated shopping
    // list is stale as soon as a serving count changes — clear it so the next
    // cart tap regenerates with the new amounts.
    private func updateServings(for meal: SuggestedMeal, to newValue: Double) {
        mealServings[meal.id] = newValue
        shoppingList = nil
        didSave = false
    }

    private func logMeal(_ meal: SuggestedMeal, goal: Goal) {
        guard let mealType = MealType(rawValue: meal.mealType) else { return }
        let date = dateForDay(meal.day)
        let servings = mealServings[meal.id] ?? 1

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

        let item = MealItem(product: product, servings: servings)
        context.insert(item)

        let newMeal = Meal(name: meal.name, mealType: mealType, items: [item], date: date)
        context.insert(newMeal)

        let log = FoodLog(meal: newMeal, goalId: goal.id, loggedAt: date)
        context.insert(log)

        loggedMealIDs.insert(meal.id)
    }
}

private struct CustomizationBar: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.secondary)
            TextField("Customize this plan (e.g. no seafood, quick meals only)", text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

private struct SuggestedMealRow: View {
    let meal: SuggestedMeal
    let servings: Double
    let isLogged: Bool
    let onTapRecipe: () -> Void
    let onLog: () -> Void
    let onServingsChange: (Double) -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.mealType).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(meal.name).font(.subheadline.weight(.medium))
                Text(meal.description).font(.caption).foregroundStyle(.secondary)
                Text("\(Int(meal.calories * servings)) kcal · P:\(Int(meal.protein * servings))g C:\(Int(meal.carbs * servings))g F:\(Int(meal.fat * servings))g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Button {
                        onServingsChange(max(1, servings - 1))
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .disabled(servings <= 1)
                    Text("×\(servings.formatted())")
                        .font(.caption.weight(.medium))
                        .frame(minWidth: 24)
                    Button {
                        onServingsChange(servings + 1)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
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
    let servings: Double
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
            .navigationTitle(servings == 1 ? meal.name : "\(meal.name) (×\(servings.formatted()))")
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
            recipe = try await MealPlanService.shared.generateRecipe(for: meal, servings: servings, allergensToAvoid: allergensToAvoid)
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
    @State private var pdfURL: URL?

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
                // Only show the share button once the PDF is actually ready —
                // ShareLink needs a real item up front, not a closure that
                // generates one on tap.
                if let pdfURL {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: pdfURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            // Regenerate whenever the list itself changes (first load, or a
            // fresh list after servings changed) rather than lazily on tap —
            // ShareLink is a declarative view, so its item needs to already
            // exist by the time this view builds its toolbar.
            .onAppear { regeneratePDF() }
            .onChange(of: shoppingList?.items.count) { _, _ in regeneratePDF() }
        }
    }

    private func regeneratePDF() {
        guard let shoppingList else { pdfURL = nil; return }
        pdfURL = ShoppingListPDF.export(shoppingList)
    }
}

// Renders a ShoppingList to a simple paginated PDF — one section per store,
// grouped by department, with per-item quantity/cost and a running total.
private enum ShoppingListPDF {
    static func export(_ list: ShoppingList) -> URL? {
        let pageWidth: CGFloat = 612   // 8.5in @ 72dpi
        let pageHeight: CGFloat = 792  // 11in @ 72dpi
        let margin: CGFloat = 36
        let contentWidth = pageWidth - margin * 2
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let storeFont = UIFont.boldSystemFont(ofSize: 15)
        let deptFont = UIFont.boldSystemFont(ofSize: 12)
        let itemFont = UIFont.systemFont(ofSize: 11)
        let secondary: [NSAttributedString.Key: Any] = [.font: itemFont, .foregroundColor: UIColor.darkGray]

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Shopping List.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: url) { context in
                var y: CGFloat = margin
                context.beginPage()

                func newPageIfNeeded(_ neededHeight: CGFloat) {
                    if y + neededHeight > pageHeight - margin {
                        context.beginPage()
                        y = margin
                    }
                }

                "Shopping List".draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: titleFont])
                y += 28

                let totalLine = "Estimated Total: $\(String(format: "%.2f", list.estimatedTotalCost))"
                totalLine.draw(at: CGPoint(x: margin, y: y), withAttributes: secondary)
                y += 26

                for (store, items) in list.byStore {
                    newPageIfNeeded(24)
                    store.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: storeFont])
                    y += 20

                    let byDepartment = Dictionary(grouping: items, by: \.department)
                    for department in byDepartment.keys.sorted() {
                        newPageIfNeeded(18)
                        department.draw(at: CGPoint(x: margin + 12, y: y), withAttributes: [.font: deptFont])
                        y += 16

                        for item in byDepartment[department]!.sorted(by: { $0.name < $1.name }) {
                            newPageIfNeeded(15)
                            let line = "\(item.name) — \(item.quantity)"
                            let maxLineWidth = contentWidth - 90
                            line.draw(
                                in: CGRect(x: margin + 24, y: y, width: maxLineWidth, height: 14),
                                withAttributes: [.font: itemFont]
                            )
                            let cost = String(format: "$%.2f", item.estimatedCost)
                            let costSize = cost.size(withAttributes: secondary)
                            cost.draw(at: CGPoint(x: pageWidth - margin - costSize.width, y: y), withAttributes: secondary)
                            y += 15
                        }
                        y += 6
                    }
                    y += 10
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
