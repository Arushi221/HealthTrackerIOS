import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "fork.knife") }

            GoalsView()
                .tabItem { Label("Goals", systemImage: "target") }

            MealPlanView()
                .tabItem { Label("Meal Plan", systemImage: "calendar") }

            FoodLogView()
                .tabItem { Label("Log", systemImage: "list.bullet") }
        }
    }
}
