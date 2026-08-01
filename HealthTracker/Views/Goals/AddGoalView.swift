import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existingGoal: Goal?

    @State private var period: GoalPeriod
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var excludedAllergens: [String]
    @State private var allergenInput: String = ""

    init(existingGoal: Goal? = nil) {
        self.existingGoal = existingGoal
        _period = State(initialValue: existingGoal?.period ?? .day)
        _calories = State(initialValue: existingGoal.map { String(Int($0.targetCalories)) } ?? "")
        _protein = State(initialValue: existingGoal.map { String(Int($0.targetProtein)) } ?? "")
        _carbs = State(initialValue: existingGoal.map { String(Int($0.targetCarbs)) } ?? "")
        _fat = State(initialValue: existingGoal.map { String(Int($0.targetFat)) } ?? "")
        _excludedAllergens = State(initialValue: existingGoal?.excludedAllergens ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Period") {
                    Picker("Goal Period", selection: $period) {
                        ForEach(GoalPeriod.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    MacroField(label: "Calories (kcal)", value: $calories)
                    MacroField(label: "Protein (g)", value: $protein)
                    MacroField(label: "Carbs (g)", value: $carbs)
                    MacroField(label: "Fat (g)", value: $fat)
                } header: {
                    Text("Macro Targets")
                } footer: {
                    if macroCalories > 0 {
                        Text("Your macros add up to \(Int(macroCalories)) kcal. If that doesn't match your calorie target, we'll scale protein/carbs/fat proportionally to match when you save.")
                    }
                }

                Section("Allergens to Exclude") {
                    HStack {
                        TextField("e.g. gluten", text: $allergenInput)
                        Button("Add") {
                            let tag = allergenInput.lowercased().trimmingCharacters(in: .whitespaces)
                            if !tag.isEmpty { excludedAllergens.append(tag); allergenInput = "" }
                        }
                        .disabled(allergenInput.isEmpty)
                    }
                    ForEach(excludedAllergens, id: \.self) { tag in
                        Text(tag)
                    }
                    .onDelete { excludedAllergens.remove(atOffsets: $0) }
                }
            }
            .navigationTitle(existingGoal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        [calories, protein, carbs, fat].allSatisfy { Double($0) != nil }
    }

    // Protein and carbs are 4 kcal/g, fat is 9 kcal/g
    private var macroCalories: Double {
        (Double(protein) ?? 0) * 4 + (Double(carbs) ?? 0) * 4 + (Double(fat) ?? 0) * 9
    }

    // If the entered macros don't add up to the calorie target, scale them
    // proportionally (keeping their ratio to each other) so they do.
    private func balancedMacros(targetCalories: Double) -> (protein: Double, carbs: Double, fat: Double) {
        var proteinG = Double(protein) ?? 0
        var carbsG = Double(carbs) ?? 0
        var fatG = Double(fat) ?? 0

        let macroCalories = proteinG * 4 + carbsG * 4 + fatG * 9
        guard macroCalories > 0, abs(macroCalories - targetCalories) > 1 else {
            return (proteinG, carbsG, fatG)
        }

        let scale = targetCalories / macroCalories
        proteinG *= scale
        carbsG *= scale
        fatG *= scale
        return (proteinG, carbsG, fatG)
    }

    private func save() {
        let targetCalories = Double(calories) ?? 0
        let balanced = balancedMacros(targetCalories: targetCalories)

        if let existingGoal {
            existingGoal.period = period
            existingGoal.targetCalories = targetCalories
            existingGoal.targetProtein = balanced.protein
            existingGoal.targetCarbs = balanced.carbs
            existingGoal.targetFat = balanced.fat
            existingGoal.excludedAllergens = excludedAllergens
        } else {
            let goal = Goal(
                period: period,
                targetCalories: targetCalories,
                targetProtein: balanced.protein,
                targetCarbs: balanced.carbs,
                targetFat: balanced.fat,
                excludedAllergens: excludedAllergens
            )
            context.insert(goal)
        }
        dismiss()
    }
}

private struct MacroField: View {
    let label: String
    @Binding var value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}
