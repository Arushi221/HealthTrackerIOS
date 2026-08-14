import SwiftUI
import SwiftData

struct AddFoodToMealView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]

    let product: FoodProduct
    let presetMealType: MealType?
    let date: Date
    let onSave: () -> Void

    @State private var mealType: MealType
    @State private var servings: String = "1"
    @State private var servingAmountText: String

    init(product: FoodProduct, presetMealType: MealType? = nil, date: Date = Date(), onSave: @escaping () -> Void) {
        self.product = product
        self.presetMealType = presetMealType
        self.date = date
        self.onSave = onSave
        _mealType = State(initialValue: presetMealType ?? .lunch)
        _servingAmountText = State(initialValue: String(Int(product.servingAmount)))
    }

    // Correcting the serving size rescales the nutrition preview live —
    // useful since Open Food Facts often has no serving data at all for a
    // product, in which case we fall back to a 100g guess that may not
    // match the actual package.
    private var correctionScale: Double {
        guard product.servingAmount > 0, let edited = Double(servingAmountText), edited > 0 else { return 1 }
        return edited / product.servingAmount
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name", value: product.name)
                    if let brand = product.brand {
                        LabeledContent("Brand", value: brand)
                    }
                    HStack {
                        Text("Serving size")
                        Spacer()
                        TextField("100", text: $servingAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text(product.servingUnit)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent(
                        "Per serving",
                        value: "\(Int(product.calories * correctionScale)) kcal  P:\(Int(product.protein * correctionScale))g  C:\(Int(product.carbs * correctionScale))g  F:\(Int(product.fat * correctionScale))g"
                    )
                    if !product.allergens.isEmpty {
                        LabeledContent("Allergens", value: product.allergens.joined(separator: ", "))
                    }
                } footer: {
                    Text("Open Food Facts doesn't always have the manufacturer's serving size. Check it against the package and correct it here if needed — the nutrition above updates to match.")
                }

                Section("Log as") {
                    if presetMealType == nil {
                        Picker("Type", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { Text($0.rawValue) }
                        }
                    }
                    HStack {
                        Text("Servings")
                        Spacer()
                        TextField("1", text: $servings)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
            }
            .navigationTitle("Add to \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { log() }
                        .disabled(Double(servings) == nil)
                }
            }
        }
    }

    private func log() {
        if correctionScale != 1 {
            product.calories *= correctionScale
            product.protein *= correctionScale
            product.carbs *= correctionScale
            product.fat *= correctionScale
            if let fiber = product.fiber { product.fiber = fiber * correctionScale }
            if let sugar = product.sugar { product.sugar = sugar * correctionScale }
            for key in product.micronutrients.keys {
                product.micronutrients[key]! *= correctionScale
            }
            product.servingAmount = Double(servingAmountText) ?? product.servingAmount
        }

        let s = Double(servings) ?? 1.0
        context.insert(product)

        let item = MealItem(product: product, servings: s)
        context.insert(item)

        let meal = Meal(name: product.name, mealType: mealType, items: [item], date: date)
        context.insert(meal)

        let goalId = goals.first(where: { $0.period == .day })?.id ?? UUID()
        let entry = FoodLog(meal: meal, goalId: goalId, loggedAt: date)
        context.insert(entry)

        onSave()
        dismiss()
    }
}
