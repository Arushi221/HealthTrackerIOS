import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var period: GoalPeriod = .day
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var excludedAllergens: [String] = []
    @State private var allergenInput: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Period") {
                    Picker("Goal Period", selection: $period) {
                        ForEach(GoalPeriod.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Macro Targets") {
                    MacroField(label: "Calories (kcal)", value: $calories)
                    MacroField(label: "Protein (g)", value: $protein)
                    MacroField(label: "Carbs (g)", value: $carbs)
                    MacroField(label: "Fat (g)", value: $fat)
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
            .navigationTitle("New Goal")
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

    private func save() {
        let goal = Goal(
            period: period,
            targetCalories: Double(calories) ?? 0,
            targetProtein: Double(protein) ?? 0,
            targetCarbs: Double(carbs) ?? 0,
            targetFat: Double(fat) ?? 0,
            excludedAllergens: excludedAllergens
        )
        context.insert(goal)
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
