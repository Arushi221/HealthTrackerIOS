import SwiftUI
import SwiftData

struct LabResultDetailView: View {
    @Environment(\.modelContext) private var context
    let testName: String
    @Query private var history: [LabResult]

    init(testName: String) {
        self.testName = testName
        _history = Query(
            filter: #Predicate<LabResult> { $0.testName == testName },
            sort: \LabResult.date,
            order: .reverse
        )
    }

    var body: some View {
        List {
            ForEach(history) { result in
                HStack {
                    Text(result.date, style: .date)
                    Spacer()
                    Text("\(formatted(result.value)) \(result.unit)")
                        .foregroundStyle(result.isInRange ? Color.primary : Color.red)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(history[index])
                }
            }
        }
        .navigationTitle(testName)
    }
}
