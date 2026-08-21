import Foundation

// Typical reference ranges shown as sensible defaults — every field is editable,
// since actual reference ranges vary by lab, sex, and age.
struct TrackedLabTest: Identifiable, Hashable {
    let name: String
    let unit: String
    let referenceLow: Double?
    let referenceHigh: Double?

    var id: String { name }
}

enum LabTestCatalog {
    static let all: [TrackedLabTest] = [
        TrackedLabTest(name: "A1c", unit: "%", referenceLow: 4.0, referenceHigh: 5.6),
        TrackedLabTest(name: "Fasting Glucose", unit: "mg/dL", referenceLow: 70, referenceHigh: 99),
        TrackedLabTest(name: "Iron", unit: "mcg/dL", referenceLow: 60, referenceHigh: 170),
        TrackedLabTest(name: "Ferritin", unit: "ng/mL", referenceLow: 20, referenceHigh: 250),
        TrackedLabTest(name: "Vitamin D", unit: "ng/mL", referenceLow: 30, referenceHigh: 100),
        TrackedLabTest(name: "Vitamin B12", unit: "pg/mL", referenceLow: 200, referenceHigh: 900),
        TrackedLabTest(name: "TSH", unit: "mIU/L", referenceLow: 0.4, referenceHigh: 4.0),
        TrackedLabTest(name: "LDL Cholesterol", unit: "mg/dL", referenceLow: nil, referenceHigh: 100),
        TrackedLabTest(name: "HDL Cholesterol", unit: "mg/dL", referenceLow: 40, referenceHigh: nil),
        TrackedLabTest(name: "Triglycerides", unit: "mg/dL", referenceLow: nil, referenceHigh: 150),
        TrackedLabTest(name: "hs-CRP", unit: "mg/L", referenceLow: nil, referenceHigh: 1.0),
        TrackedLabTest(name: "TPO Antibodies", unit: "IU/mL", referenceLow: nil, referenceHigh: 35),
        TrackedLabTest(name: "Thyroglobulin Antibodies (TgAb)", unit: "IU/mL", referenceLow: nil, referenceHigh: 4.5),
        TrackedLabTest(name: "ANA Screen", unit: "index", referenceLow: nil, referenceHigh: 1.0),
        TrackedLabTest(name: "DHEA Sulfate", unit: "mcg/dL", referenceLow: 65, referenceHigh: 380),
        TrackedLabTest(name: "Leptin", unit: "ng/mL", referenceLow: 1, referenceHigh: 25)
    ]
}
