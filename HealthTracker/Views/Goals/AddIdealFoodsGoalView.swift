import SwiftUI
import SwiftData

struct AddIdealFoodsGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let existingGoal: IdealFoodGoal?

    @State private var foods: [String]
    @State private var foodInput: String = ""
    @State private var dailyTarget: String

    init(existingGoal: IdealFoodGoal? = nil) {
        self.existingGoal = existingGoal
        _foods = State(initialValue: existingGoal?.foods ?? [])
        _dailyTarget = State(initialValue: existingGoal.map { String($0.dailyTarget) } ?? "2")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("e.g. salmon", text: $foodInput)
                        Button("Add") {
                            let food = foodInput.lowercased().trimmingCharacters(in: .whitespaces)
                            if !food.isEmpty, !foods.contains(food) {
                                foods.append(food)
                            }
                            foodInput = ""
                        }
                        .disabled(foodInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if foods.isEmpty {
                        Text("Add foods you're trying to eat more of — Claude checks your logged meals against this list.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(foods, id: \.self) { food in
                        Text(food)
                    }
                    .onDelete { foods.remove(atOffsets: $0) }
                } header: {
                    Text("Ideal Foods")
                }

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
                } footer: {
                    Text("Week and month targets scale automatically from this daily number.")
                }
            }
            .navigationTitle(existingGoal == nil ? "Set Ideal Foods" : "Edit Ideal Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(foods.isEmpty || Int(dailyTarget) == nil)
                }
            }
        }
    }

    private func save() {
        let target = Int(dailyTarget) ?? 2
        if let existingGoal {
            existingGoal.foods = foods
            existingGoal.dailyTarget = target
        } else {
            let goal = IdealFoodGoal(foods: foods, dailyTarget: target)
            context.insert(goal)
        }
        dismiss()
    }
}
