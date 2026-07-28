import SwiftUI
import SwiftData

struct AddNutrientGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<NutrientGoal> { $0.isActive }) private var existingGoals: [NutrientGoal]

    @State private var selectedNutrient: TrackedNutrient?
    @State private var dailyTarget: String = ""

    private var availableNutrients: [TrackedNutrient] {
        let trackedKeys = Set(existingGoals.map { $0.nutrientKey })
        return NutrientCatalog.all.filter { !trackedKeys.contains($0.key) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nutrient") {
                    Picker("Nutrient", selection: $selectedNutrient) {
                        ForEach(availableNutrients) { nutrient in
                            Text(nutrient.displayName).tag(Optional(nutrient))
                        }
                    }
                }

                Section("Daily Target") {
                    HStack {
                        TextField("0", text: $dailyTarget)
                            .keyboardType(.decimalPad)
                        Text(selectedNutrient?.unit ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Nutrient Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if selectedNutrient == nil {
                    selectedNutrient = availableNutrients.first
                }
            }
        }
    }

    private var isValid: Bool {
        selectedNutrient != nil && Double(dailyTarget) != nil
    }

    private func save() {
        guard let nutrient = selectedNutrient else { return }
        let goal = NutrientGoal(
            nutrientKey: nutrient.key,
            displayName: nutrient.displayName,
            unit: nutrient.unit,
            dailyTarget: Double(dailyTarget) ?? 0
        )
        context.insert(goal)
        dismiss()
    }
}
