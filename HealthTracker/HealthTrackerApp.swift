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
                FoodLog.self,
                NutrientGoal.self,
                LabResult.self,
                FoodCategoryGoal.self
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
