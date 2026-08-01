import SwiftUI
import SwiftData

struct SuggestedNutrientGoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let labResults: [LabResult]

    @State private var suggestions: [NutrientGoalSuggestion] = []
    @State private var selectedKeys: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Analyzing your lab results…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage).foregroundStyle(.secondary)
                        Button("Try Again") { Task { await loadSuggestions() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if suggestions.isEmpty && hasLoaded {
                    Text("No nutrient suggestions from your current results.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(suggestions) { suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isSelected: selectedKeys.contains(suggestion.nutrientKey)
                        ) {
                            if selectedKeys.contains(suggestion.nutrientKey) {
                                selectedKeys.remove(suggestion.nutrientKey)
                            } else {
                                selectedKeys.insert(suggestion.nutrientKey)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Suggested Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applySelected() }
                        .disabled(selectedKeys.isEmpty)
                }
            }
            .task {
                await loadSuggestions()
            }
        }
    }

    private func loadSuggestions() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await NutrientGoalSuggestionService.shared.suggestGoals(from: labResults)
            suggestions = result
            selectedKeys = Set(result.map(\.nutrientKey))
        } catch {
            errorMessage = (error as? AnthropicServiceError)?.errorDescription ?? "Couldn't generate suggestions."
        }
        hasLoaded = true
        isLoading = false
    }

    private func applySelected() {
        let existing = (try? context.fetch(FetchDescriptor<NutrientGoal>())) ?? []

        for suggestion in suggestions where selectedKeys.contains(suggestion.nutrientKey) {
            guard let catalogEntry = NutrientCatalog.all.first(where: { $0.key == suggestion.nutrientKey }) else { continue }

            if let goal = existing.first(where: { $0.nutrientKey == suggestion.nutrientKey }) {
                goal.dailyTarget = suggestion.dailyTarget
            } else {
                let goal = NutrientGoal(
                    nutrientKey: catalogEntry.key,
                    displayName: catalogEntry.displayName,
                    unit: catalogEntry.unit,
                    dailyTarget: suggestion.dailyTarget
                )
                context.insert(goal)
            }
        }
        dismiss()
    }
}

private struct SuggestionRow: View {
    let suggestion: NutrientGoalSuggestion
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayName)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(formatted(suggestion.dailyTarget)) \(unit)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(suggestion.rationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        NutrientCatalog.all.first { $0.key == suggestion.nutrientKey }?.displayName ?? suggestion.nutrientKey
    }

    private var unit: String {
        NutrientCatalog.all.first { $0.key == suggestion.nutrientKey }?.unit ?? ""
    }
}
