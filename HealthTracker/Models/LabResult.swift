import Foundation
import SwiftData

@Model
final class LabResult {
    var id: UUID
    var testName: String
    var value: Double
    var unit: String
    var referenceLow: Double?
    var referenceHigh: Double?
    var date: Date

    var isInRange: Bool {
        if let low = referenceLow, value < low { return false }
        if let high = referenceHigh, value > high { return false }
        return true
    }

    init(
        testName: String,
        value: Double,
        unit: String,
        referenceLow: Double? = nil,
        referenceHigh: Double? = nil,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.testName = testName
        self.value = value
        self.unit = unit
        self.referenceLow = referenceLow
        self.referenceHigh = referenceHigh
        self.date = date
    }
}
