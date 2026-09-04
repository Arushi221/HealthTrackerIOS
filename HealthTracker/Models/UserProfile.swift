import Foundation
import SwiftData

enum BiologicalSex: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case other = "Other"

    // Mifflin-St Jeor's constant term, which differs by sex; "Other" splits
    // the difference rather than guessing one way or the other.
    var mifflinStJeorConstant: Double {
        switch self {
        case .male: return 5
        case .female: return -161
        case .other: return -78
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "Sedentary"
    case light = "Lightly Active"
    case moderate = "Moderately Active"
    case active = "Active"
    case veryActive = "Very Active"

    var description: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Hard exercise 6-7 days/week"
        case .veryActive: return "Very hard exercise & physical job"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    // Rough thresholds mapping a 7-day average step count (from Apple
    // Health/Apple Watch) onto the standard activity-level tiers above.
    static func forAverageDailySteps(_ steps: Double) -> ActivityLevel {
        switch steps {
        case ..<5000: return .sedentary
        case 5000..<7500: return .light
        case 7500..<10000: return .moderate
        case 10000..<12500: return .active
        default: return .veryActive
        }
    }
}

// A single settings record for the whole app — grocery budget and preferred
// stores, used by the meal planner and shopping list; body metrics used to
// estimate maintenance calories for the weight-goal picker in Goals.
@Model
final class UserProfile {
    var id: UUID
    var weeklyBudget: Double = 0
    var preferredStores: [String] = []
    var preferIndianMediterranean: Bool = false

    var heightInches: Double = 0
    var weightLbs: Double = 0
    var ageYears: Int = 0
    var biologicalSex: BiologicalSex = BiologicalSex.female
    var activityLevel: ActivityLevel = ActivityLevel.moderate
    var useHealthKitActivityLevel: Bool = false

    var bmi: Double? {
        guard heightInches > 0, weightLbs > 0 else { return nil }
        return 703 * weightLbs / (heightInches * heightInches)
    }

    // Mifflin-St Jeor BMR, scaled to activity level for an estimated total
    // daily energy expenditure (maintenance calories) — the standard formula
    // for this, more accurate than BMI alone since it also accounts for age
    // and sex rather than just height and weight.
    var estimatedMaintenanceCalories: Double? {
        guard heightInches > 0, weightLbs > 0, ageYears > 0 else { return nil }
        let weightKg = weightLbs * 0.45359237
        let heightCm = heightInches * 2.54
        let bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears) + biologicalSex.mifflinStJeorConstant
        return bmr * activityLevel.multiplier
    }

    init(
        weeklyBudget: Double = 0,
        preferredStores: [String] = [],
        preferIndianMediterranean: Bool = false,
        heightInches: Double = 0,
        weightLbs: Double = 0,
        ageYears: Int = 0,
        biologicalSex: BiologicalSex = .female,
        activityLevel: ActivityLevel = .moderate,
        useHealthKitActivityLevel: Bool = false
    ) {
        self.id = UUID()
        self.weeklyBudget = weeklyBudget
        self.preferredStores = preferredStores
        self.preferIndianMediterranean = preferIndianMediterranean
        self.heightInches = heightInches
        self.weightLbs = weightLbs
        self.ageYears = ageYears
        self.biologicalSex = biologicalSex
        self.activityLevel = activityLevel
        self.useHealthKitActivityLevel = useHealthKitActivityLevel
    }
}
