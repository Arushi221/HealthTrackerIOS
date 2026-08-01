import SwiftUI

struct EditNutrientGoalView: View {
    @Environment(\.dismiss) private var dismiss
    let goal: NutrientGoal

    @State private var dailyTarget: String

    init(goal: NutrientGoal) {
        self.goal = goal
        _dailyTarget = State(initialValue: String(Int(goal.dailyTarget)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(goal.displayName) {
                    HStack {
                        Text("Daily Target")
                        Spacer()
                        TextField("0", text: $dailyTarget)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(goal.unit)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        goal.dailyTarget = Double(dailyTarget) ?? goal.dailyTarget
                        dismiss()
                    }
                    .disabled(Double(dailyTarget) == nil)
                }
            }
        }
    }
}
