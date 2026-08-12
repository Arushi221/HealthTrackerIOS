import SwiftUI
import SwiftData

// Log a custom food by typing its macros directly — no search needed.
// Calories are computed automatically (4 kcal/g protein & carbs, 9 kcal/g fat)
// as protein/carbs/fat are entered, so the two always stay consistent.
struct QuickAddFoodView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]

    let mealType: MealType
    let date: Date

    @State private var name: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""

    private var calories: Double {
        (Double(protein) ?? 0) * 4 + (Double(carbs) ?? 0) * 4 + (Double(fat) ?? 0) * 9
    }

    private var isValid: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let macros = [protein, carbs, fat]
        let hasAnyMacro = macros.contains { Double($0).map { $0 > 0 } ?? false }
        let allValidOrEmpty = macros.allSatisfy { $0.isEmpty || Double($0) != nil }
        return hasName && hasAnyMacro && allValidOrEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                }

                Section("Macros (grams)") {
                    MacroField(label: "Protein", value: $protein)
                    MacroField(label: "Carbs", value: $carbs)
                    MacroField(label: "Fat", value: $fat)
                }

                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        Text("\(Int(calories)) kcal")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Calculated automatically from protein, carbs, and fat — no need to enter it yourself.")
                }
            }
            .navigationTitle("Quick Add to \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { log() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func log() {
        let product = FoodProduct(
            name: name.trimmingCharacters(in: .whitespaces),
            servingAmount: 1,
            servingUnit: "serving",
            calories: calories,
            protein: Double(protein) ?? 0,
            carbs: Double(carbs) ?? 0,
            fat: Double(fat) ?? 0
        )
        context.insert(product)

        let item = MealItem(product: product, servings: 1)
        context.insert(item)

        let meal = Meal(name: product.name, mealType: mealType, items: [item], date: date)
        context.insert(meal)

        let goalId = goals.first(where: { $0.period == .day })?.id ?? UUID()
        let entry = FoodLog(meal: meal, goalId: goalId, loggedAt: date)
        context.insert(entry)

        dismiss()
    }
}

private struct MacroField: View {
    let label: String
    @Binding var value: String

    var body: some View {
        HStack {
            Text("\(label) (g)")
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}
