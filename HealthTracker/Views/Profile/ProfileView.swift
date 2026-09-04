import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @State private var weeklyBudget: String = ""
    @State private var preferredStores: [String] = []
    @State private var storeInput: String = ""
    @State private var preferIndianMediterranean: Bool = false
    @State private var heightInches: String = ""
    @State private var weightLbs: String = ""
    @State private var ageYears: String = ""
    @State private var biologicalSex: BiologicalSex = .female
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var useHealthKitActivityLevel: Bool = false
    @State private var detectedAverageSteps: Double?
    @State private var healthKitErrorMessage: String?
    @Environment(\.scenePhase) private var scenePhase

    private var profile: UserProfile? { profiles.first }

    private var bmi: Double? {
        guard let h = Double(heightInches), let w = Double(weightLbs), h > 0, w > 0 else { return nil }
        return 703 * w / (h * h)
    }

    private var estimatedMaintenanceCalories: Double? {
        guard let h = Double(heightInches), let w = Double(weightLbs), let age = Int(ageYears),
              h > 0, w > 0, age > 0 else { return nil }
        let weightKg = w * 0.45359237
        let heightCm = h * 2.54
        let bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + biologicalSex.mifflinStJeorConstant
        return bmr * activityLevel.multiplier
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Height (in)")
                        Spacer()
                        TextField("e.g. 66", text: $heightInches)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Weight (lb)")
                        Spacer()
                        TextField("e.g. 150", text: $weightLbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("e.g. 30", text: $ageYears)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Picker("Sex", selection: $biologicalSex) {
                        ForEach(BiologicalSex.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .disabled(useHealthKitActivityLevel)
                    Toggle("Estimate from Apple Health steps", isOn: $useHealthKitActivityLevel)
                    if useHealthKitActivityLevel, let detectedAverageSteps {
                        Text("~\(Int(detectedAverageSteps.rounded())) steps/day average (last 7 days)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let healthKitErrorMessage {
                        Text(healthKitErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if let bmi {
                        LabeledContent("BMI", value: String(format: "%.1f", bmi))
                    }
                    if let estimatedMaintenanceCalories {
                        LabeledContent("Est. Maintenance Calories", value: "\(Int(estimatedMaintenanceCalories.rounded())) kcal")
                    }
                } header: {
                    Text("Body Metrics")
                } footer: {
                    Text("Used to estimate your maintenance calories (via the Mifflin-St Jeor formula) as a starting point for the weight-goal picker in Goals.")
                }

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
            .onChange(of: heightInches) { _, _ in save() }
            .onChange(of: weightLbs) { _, _ in save() }
            .onChange(of: ageYears) { _, _ in save() }
            .onChange(of: biologicalSex) { _, _ in save() }
            .onChange(of: activityLevel) { _, _ in save() }
            .onChange(of: useHealthKitActivityLevel) { _, newValue in
                save()
                if newValue { Task { await detectActivityLevelFromHealthKit() } }
            }
            .task(id: useHealthKitActivityLevel) {
                if useHealthKitActivityLevel { await detectActivityLevelFromHealthKit() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, useHealthKitActivityLevel {
                    Task { await detectActivityLevelFromHealthKit() }
                }
            }
        }
    }

    private func detectActivityLevelFromHealthKit() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            let avgSteps = try await HealthKitService.shared.averageDailySteps()
            detectedAverageSteps = avgSteps
            healthKitErrorMessage = nil
            activityLevel = ActivityLevel.forAverageDailySteps(avgSteps)
        } catch {
            healthKitErrorMessage = "Couldn't read step data from Apple Health."
        }
    }

    private func loadFromProfile() {
        guard let profile else { return }
        weeklyBudget = profile.weeklyBudget > 0 ? String(Int(profile.weeklyBudget)) : ""
        preferredStores = profile.preferredStores
        preferIndianMediterranean = profile.preferIndianMediterranean
        heightInches = profile.heightInches > 0 ? String(Int(profile.heightInches)) : ""
        weightLbs = profile.weightLbs > 0 ? String(Int(profile.weightLbs)) : ""
        ageYears = profile.ageYears > 0 ? String(profile.ageYears) : ""
        biologicalSex = profile.biologicalSex
        activityLevel = profile.activityLevel
        useHealthKitActivityLevel = profile.useHealthKitActivityLevel
    }

    private func save() {
        let budget = Double(weeklyBudget) ?? 0
        let height = Double(heightInches) ?? 0
        let weight = Double(weightLbs) ?? 0
        let age = Int(ageYears) ?? 0

        if let profile {
            profile.weeklyBudget = budget
            profile.preferredStores = preferredStores
            profile.preferIndianMediterranean = preferIndianMediterranean
            profile.heightInches = height
            profile.weightLbs = weight
            profile.ageYears = age
            profile.biologicalSex = biologicalSex
            profile.activityLevel = activityLevel
            profile.useHealthKitActivityLevel = useHealthKitActivityLevel
        } else {
            let newProfile = UserProfile(
                weeklyBudget: budget,
                preferredStores: preferredStores,
                preferIndianMediterranean: preferIndianMediterranean,
                heightInches: height,
                weightLbs: weight,
                ageYears: age,
                biologicalSex: biologicalSex,
                activityLevel: activityLevel,
                useHealthKitActivityLevel: useHealthKitActivityLevel
            )
            context.insert(newProfile)
        }
    }
}
