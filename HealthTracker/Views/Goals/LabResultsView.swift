import SwiftUI
import SwiftData

struct LabResultsView: View {
    @Query(sort: \LabResult.date, order: .reverse) private var results: [LabResult]
    @State private var showingAddResult = false
    @State private var showingSuggestions = false

    private var testNames: [String] {
        Array(Set(results.map(\.testName))).sorted()
    }

    private func latest(for testName: String) -> LabResult? {
        results.first { $0.testName == testName }
    }

    private var latestResults: [LabResult] {
        testNames.compactMap { latest(for: $0) }
    }

    var body: some View {
        List {
            if testNames.isEmpty {
                Text("No lab results yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(testNames, id: \.self) { name in
                    if let latest = latest(for: name) {
                        NavigationLink {
                            LabResultDetailView(testName: name)
                        } label: {
                            LabResultRow(result: latest)
                        }
                    }
                }
            }
        }
        .navigationTitle("Lab Results")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddResult = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingSuggestions = true
                } label: {
                    Label("Suggest Nutrient Goals", systemImage: "wand.and.stars")
                }
                .disabled(testNames.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddResult) {
            AddLabResultView()
        }
        .sheet(isPresented: $showingSuggestions) {
            SuggestedNutrientGoalsView(labResults: latestResults)
        }
    }
}

private struct LabResultRow: View {
    let result: LabResult

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.testName).font(.subheadline.weight(.medium))
                Text(result.date, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formatted(result.value)) \(result.unit)")
                    .font(.subheadline)
                    .foregroundStyle(result.isInRange ? Color.primary : Color.red)
                if let low = result.referenceLow, let high = result.referenceHigh {
                    Text("\(formatted(low))\u{2013}\(formatted(high))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

func formatted(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
}
