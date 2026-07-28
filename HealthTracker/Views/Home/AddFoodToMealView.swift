import SwiftUI
import SwiftData

struct AddFoodToMealView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]

    let product: FoodProduct
    let presetMealType: MealType?
    let onSave: () -> Void

    @State private var mealType: MealType
    @State private var servings: String = "1"

    init(product: FoodProduct, presetMealType: MealType? = nil, onSave: @escaping () -> Void) {
        self.product = product
        self.presetMealType = presetMealType
        self.onSave = onSave
        _mealType = State(initialValue: presetMealType ?? .lunch)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    LabeledContent("Name", value: product.name)
                    if let brand = product.brand {
                        LabeledContent("Brand", value: brand)
                    }
                    LabeledContent("Per serving", value: "\(Int(product.calories)) kcal  P:\(Int(product.protein))g  C:\(Int(product.carbs))g  F:\(Int(product.fat))g")
                    if !product.allergens.isEmpty {
                        LabeledContent("Allergens", value: product.allergens.joined(separator: ", "))
                    }
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
        let s = Double(servings) ?? 1.0
        context.insert(product)

        let item = MealItem(product: product, servings: s)
        context.insert(item)

        let meal = Meal(name: product.name, mealType: mealType, items: [item])
        context.insert(meal)

        let goalId = goals.first(where: { $0.period == .day })?.id ?? UUID()
        let entry = FoodLog(meal: meal, goalId: goalId)
        context.insert(entry)

        onSave()
        dismiss()
    }
}
