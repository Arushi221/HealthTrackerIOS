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
    @State private var isAdjusting = false

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
                        .onChange(of: calories) { _, _ in rescaleAllMacros() }
                    MacroField(label: "Protein (g)", value: $protein)
                        .onChange(of: protein) { _, _ in rebalance(changed: .protein) }
                    MacroField(label: "Carbs (g)", value: $carbs)
                        .onChange(of: carbs) { _, _ in rebalance(changed: .carbs) }
                    MacroField(label: "Fat (g)", value: $fat)
                        .onChange(of: fat) { _, _ in rebalance(changed: .fat) }
                } header: {
                    Text("Macro Targets")
                } footer: {
                    Text("Editing any macro automatically adjusts the others to keep them adding up to your calorie target.")
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

    private enum MacroKind { case protein, carbs, fat }

    // When one macro changes, rescale the other two (preserving their ratio to
    // each other) so all three keep adding up to the calorie target — live,
    // not just on save.
    private func rebalance(changed: MacroKind) {
        guard !isAdjusting, let cal = Double(calories), cal > 0 else { return }

        let p = Double(protein) ?? 0
        let c = Double(carbs) ?? 0
        let f = Double(fat) ?? 0

        let changedCalories: Double
        let otherTotal: Double
        switch changed {
        case .protein: changedCalories = p * 4; otherTotal = c * 4 + f * 9
        case .carbs:   changedCalories = c * 4; otherTotal = p * 4 + f * 9
        case .fat:     changedCalories = f * 9; otherTotal = p * 4 + c * 4
        }

        let remaining = max(0, cal - changedCalories)
        guard otherTotal > 0 else { return }
        let scale = remaining / otherTotal

        isAdjusting = true
        switch changed {
        case .protein:
            carbs = String(Int((c * scale).rounded()))
            fat = String(Int((f * scale).rounded()))
        case .carbs:
            protein = String(Int((p * scale).rounded()))
            fat = String(Int((f * scale).rounded()))
        case .fat:
            protein = String(Int((p * scale).rounded()))
            carbs = String(Int((c * scale).rounded()))
        }
        isAdjusting = false
    }

    // When the calorie target changes, rescale all three macros to match it,
    // keeping their existing ratio to each other.
    private func rescaleAllMacros() {
        guard !isAdjusting, let cal = Double(calories), cal > 0 else { return }

        let p = Double(protein) ?? 0
        let c = Double(carbs) ?? 0
        let f = Double(fat) ?? 0
        let total = p * 4 + c * 4 + f * 9

        isAdjusting = true
        if total > 0 {
            let scale = cal / total
            protein = String(Int((p * scale).rounded()))
            carbs = String(Int((c * scale).rounded()))
            fat = String(Int((f * scale).rounded()))
        } else {
            // No macros set yet — seed a standard 30/40/30 protein/carbs/fat split
            protein = String(Int((cal * 0.30 / 4).rounded()))
            carbs = String(Int((cal * 0.40 / 4).rounded()))
            fat = String(Int((cal * 0.30 / 9).rounded()))
        }
        isAdjusting = false
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
