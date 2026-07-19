import SwiftUI
import SwiftData

@main
struct HealthTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for:
                FoodProduct.self,
                MealItem.self,
                Meal.self,
                Goal.self,
                FoodLog.self
            )
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
