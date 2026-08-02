import SwiftUI
import SwiftData

struct AddFoodCategoryGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let category: FoodCategory
    let existingGoal: FoodCategoryGoal?

    @State private var dailyTarget: String

    init(category: FoodCategory, existingGoal: FoodCategoryGoal? = nil) {
        self.category = category
        self.existingGoal = existingGoal
        _dailyTarget = State(initialValue: existingGoal.map { String($0.dailyTarget) } ?? "2")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Daily Target")
                        Spacer()
                        TextField("2", text: $dailyTarget)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("foods")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(category.displayName)
                } footer: {
                    Text("Week and month targets scale automatically from this daily number.")
                }
            }
            .navigationTitle(existingGoal == nil ? "Set Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(Int(dailyTarget) == nil)
                }
            }
        }
    }

    private func save() {
        let target = Int(dailyTarget) ?? 2
        if let existingGoal {
            existingGoal.dailyTarget = target
        } else {
            let goal = FoodCategoryGoal(categoryKey: category.key, dailyTarget: target)
            context.insert(goal)
        }
        dismiss()
    }
}
