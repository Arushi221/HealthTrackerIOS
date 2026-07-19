import SwiftUI
import SwiftData

struct FoodLogView: View {
    @Query(sort: \FoodLog.loggedAt, order: .reverse) private var logs: [FoodLog]

    private var grouped: [(String, [FoodLog])] {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        let dict = Dictionary(grouping: logs) { fmt.string(from: $0.loggedAt) }
        return dict.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { date, dayLogs in
                    Section(date) {
                        ForEach(dayLogs) { log in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.meal.name).font(.subheadline.weight(.medium))
                                Text("\(Int(log.meal.totalCalories)) kcal  · \(log.meal.mealType.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Food Log")
        }
    }
}
