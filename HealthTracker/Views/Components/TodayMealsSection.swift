import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

// Drag payload for moving a logged meal between meal-type sections — carries
// just the FoodLog's id, resolved back to the real model on drop since
// SwiftData models can't conform to Transferable directly.
private struct MealLogTransfer: Codable, Transferable {
    let logID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .mealLogTransfer)
    }
}

private extension UTType {
    static var mealLogTransfer: UTType {
        UTType(exportedAs: "com.healthtracker.mealLogTransfer")
    }
}

struct TodayMealsSection: View {
    let logs: [FoodLog]
    let date: Date

    @Environment(\.modelContext) private var context
    @Query private var allLogs: [FoodLog]
    @State private var feedback: String?

    private func logs(for mealType: MealType) -> [FoodLog] {
        logs.filter { $0.meal.mealType == mealType }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Meals")
                        .font(.headline)
                    Spacer()
                    if let feedback {
                        Text(feedback)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                Text("Swipe right to copy yesterday's meals")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(MealType.allCases, id: \.self) { mealType in
                MealTypeSection(mealType: mealType, logs: logs(for: mealType), date: date, onDropLog: moveLog)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard value.translation.width > 60, abs(value.translation.height) < 50 else { return }
                    copyYesterdaysMeals()
                }
        )
    }

    private func copyYesterdaysMeals() {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { return }
        let yesterdayLogs = allLogs.filter { cal.isDate($0.loggedAt, inSameDayAs: yesterday) }

        guard !yesterdayLogs.isEmpty else {
            showFeedback("No meals logged yesterday")
            return
        }

        for log in yesterdayLogs {
            let newItems = log.meal.items.map { MealItem(product: $0.product, servings: $0.servings) }
            newItems.forEach { context.insert($0) }

            let newMeal = Meal(name: log.meal.name, mealType: log.meal.mealType, items: newItems, date: date)
            context.insert(newMeal)

            let newLog = FoodLog(meal: newMeal, goalId: log.goalId, loggedAt: date)
            context.insert(newLog)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showFeedback("Copied \(yesterdayLogs.count) meal\(yesterdayLogs.count == 1 ? "" : "s") from yesterday")
    }

    private func moveLog(id: UUID, to mealType: MealType) {
        guard let log = logs.first(where: { $0.id == id }), log.meal.mealType != mealType else { return }
        log.meal.mealType = mealType
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func showFeedback(_ text: String) {
        withAnimation { feedback = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            if feedback == text {
                withAnimation { feedback = nil }
            }
        }
    }
}

private struct MealTypeSection: View {
    let mealType: MealType
    let logs: [FoodLog]
    let date: Date
    let onDropLog: (UUID, MealType) -> Void

    @State private var showingSearch = false
    @State private var showingQuickAdd = false
    @State private var isDropTargeted = false

    private var totalCalories: Double {
        logs.reduce(0) { $0 + $1.meal.totalCalories }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mealType.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !logs.isEmpty {
                    Text("\(Int(totalCalories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showingQuickAdd = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }

            if logs.isEmpty {
                Text(isDropTargeted ? "Drop here to move to \(mealType.rawValue)" : "No items logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(logs) { log in
                    MealRow(log: log)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .dropDestination(for: MealLogTransfer.self) { items, _ in
            for item in items { onDropLog(item.logID, mealType) }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .sheet(isPresented: $showingSearch) {
            FoodSearchView(mealType: mealType, date: date)
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddFoodView(mealType: mealType, date: date)
        }
    }
}

private struct MealRow: View {
    let log: FoodLog
    @Environment(\.modelContext) private var context
    @State private var showingDetail = false

    private var meal: Meal { log.meal }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name).font(.subheadline.weight(.medium))
                Text(meal.mealType.rawValue).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(meal.totalCalories)) kcal").font(.subheadline)
                Text("P:\(Int(meal.totalProtein))g  C:\(Int(meal.totalCarbs))g  F:\(Int(meal.totalFat))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                context.delete(meal)
                context.delete(log)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture { showingDetail = true }
        .draggable(MealLogTransfer(logID: log.id)) {
            MealDragPreview(meal: meal)
        }
        .sheet(isPresented: $showingDetail) {
            MealDetailView(meal: meal)
        }
    }
}

private struct MealDragPreview: View {
    let meal: Meal

    var body: some View {
        HStack {
            Text(meal.name).font(.subheadline.weight(.medium))
            Text("\(Int(meal.totalCalories)) kcal").font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct MealDetailView: View {
    let meal: Meal
    @Environment(\.dismiss) private var dismiss

    private var presentMicronutrients: [MicronutrientCatalog.Entry] {
        MicronutrientCatalog.all.filter { meal.totalAmount(of: $0.key) > 0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Macros") {
                    LabeledContent("Calories", value: "\(Int(meal.totalCalories)) kcal")
                    LabeledContent("Protein", value: "\(Int(meal.totalProtein)) g")
                    LabeledContent("Carbs", value: "\(Int(meal.totalCarbs)) g")
                    LabeledContent("Fat", value: "\(Int(meal.totalFat)) g")
                    if let fiber = meal.totalFiber {
                        LabeledContent("Fiber", value: "\(Int(fiber)) g")
                    }
                    if let sugar = meal.totalSugar {
                        LabeledContent("Sugar", value: "\(Int(sugar)) g")
                    }
                }

                let addedSugar = meal.totalAmount(of: "added_sugar")
                if addedSugar > 0 {
                    Section {
                        LabeledContent("Added Sugar", value: "\(Int(addedSugar)) g")
                    }
                }

                if !presentMicronutrients.isEmpty {
                    Section("Vitamins & Minerals") {
                        ForEach(presentMicronutrients, id: \.key) { entry in
                            LabeledContent(entry.label, value: entry.formatted(meal.totalAmount(of: entry.key)))
                        }
                    }
                } else {
                    Section {
                        Text("No detailed vitamin/mineral data available for this food.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private enum MicronutrientCatalog {
    struct Entry {
        let key: String
        let label: String
        let unit: String

        // mg/µg amounts round to whole numbers; gram amounts (fats) keep one decimal.
        func formatted(_ value: Double) -> String {
            unit == "g" ? String(format: "%.1f %@", value, unit) : "\(Int(value.rounded())) \(unit)"
        }
    }

    static let all: [Entry] = [
        Entry(key: "saturated_fat", label: "Saturated Fat", unit: "g"),
        Entry(key: "trans_fat", label: "Trans Fat", unit: "g"),
        Entry(key: "omega_3", label: "Omega-3", unit: "g"),
        Entry(key: "omega_6", label: "Omega-6", unit: "g"),
        Entry(key: "sodium", label: "Sodium", unit: "mg"),
        Entry(key: "calcium", label: "Calcium", unit: "mg"),
        Entry(key: "iron", label: "Iron", unit: "mg"),
        Entry(key: "potassium", label: "Potassium", unit: "mg"),
        Entry(key: "magnesium", label: "Magnesium", unit: "mg"),
        Entry(key: "zinc", label: "Zinc", unit: "mg"),
        Entry(key: "phosphorus", label: "Phosphorus", unit: "mg"),
        Entry(key: "vitamin_a", label: "Vitamin A", unit: "µg"),
        Entry(key: "vitamin_c", label: "Vitamin C", unit: "mg"),
        Entry(key: "vitamin_d", label: "Vitamin D", unit: "µg"),
        Entry(key: "vitamin_e", label: "Vitamin E", unit: "mg"),
        Entry(key: "vitamin_k", label: "Vitamin K", unit: "µg"),
        Entry(key: "vitamin_b12", label: "Vitamin B12", unit: "µg"),
        Entry(key: "vitamin_b6", label: "Vitamin B6", unit: "mg"),
        Entry(key: "folate", label: "Folate", unit: "µg")
    ]
}
