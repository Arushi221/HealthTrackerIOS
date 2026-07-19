import SwiftUI

struct MealPlanView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Meal Planning")
                    .font(.headline)
                Text("Set your goals and food preferences first, then meal suggestions will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Meal Plan")
        }
    }
}
