import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @State private var weeklyBudget: String = ""
    @State private var preferredStores: [String] = []
    @State private var storeInput: String = ""
    @State private var preferIndianMediterranean: Bool = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Weekly Budget")
                        Spacer()
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0", text: $weeklyBudget)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } header: {
                    Text("Grocery Budget")
                } footer: {
                    Text("Used to keep meal plan suggestions and the shopping list within budget.")
                }

                Section("Preferred Stores") {
                    HStack {
                        TextField("e.g. Trader Joe's", text: $storeInput)
                        Button("Add") {
                            let name = storeInput.trimmingCharacters(in: .whitespaces)
                            if !name.isEmpty { preferredStores.append(name); storeInput = "" }
                        }
                        .disabled(storeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if preferredStores.isEmpty {
                        Text("Add the stores you shop at so the shopping list can group items by store.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(preferredStores, id: \.self) { store in
                        Text(store)
                    }
                    .onDelete { preferredStores.remove(atOffsets: $0) }
                }

                Section {
                    Toggle("Indian & Mediterranean", isOn: $preferIndianMediterranean)
                } header: {
                    Text("Cuisine")
                } footer: {
                    Text("When on, the meal planner will primarily suggest Indian and Mediterranean dishes.")
                }
            }
            .navigationTitle("Profile")
            .onAppear(perform: loadFromProfile)
            .onChange(of: weeklyBudget) { _, _ in save() }
            .onChange(of: preferredStores) { _, _ in save() }
            .onChange(of: preferIndianMediterranean) { _, _ in save() }
        }
    }

    private func loadFromProfile() {
        guard let profile else { return }
        weeklyBudget = profile.weeklyBudget > 0 ? String(Int(profile.weeklyBudget)) : ""
        preferredStores = profile.preferredStores
        preferIndianMediterranean = profile.preferIndianMediterranean
    }

    private func save() {
        let budget = Double(weeklyBudget) ?? 0
        if let profile {
            profile.weeklyBudget = budget
            profile.preferredStores = preferredStores
            profile.preferIndianMediterranean = preferIndianMediterranean
        } else {
            let newProfile = UserProfile(
                weeklyBudget: budget,
                preferredStores: preferredStores,
                preferIndianMediterranean: preferIndianMediterranean
            )
            context.insert(newProfile)
        }
    }
}
