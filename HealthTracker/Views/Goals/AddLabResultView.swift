import SwiftUI
import SwiftData

struct AddLabResultView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTest: TrackedLabTest?
    @State private var customName: String = ""
    @State private var value: String = ""
    @State private var unit: String = ""
    @State private var referenceLow: String = ""
    @State private var referenceHigh: String = ""
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Test") {
                    Picker("Test", selection: $selectedTest) {
                        Text("Custom").tag(Optional<TrackedLabTest>.none)
                        ForEach(LabTestCatalog.all) { test in
                            Text(test.name).tag(Optional(test))
                        }
                    }
                    .onChange(of: selectedTest) { _, newValue in
                        guard let newValue else { return }
                        unit = newValue.unit
                        referenceLow = newValue.referenceLow.map { String($0) } ?? ""
                        referenceHigh = newValue.referenceHigh.map { String($0) } ?? ""
                    }

                    if selectedTest == nil {
                        TextField("Test name", text: $customName)
                    }
                }

                Section("Result") {
                    HStack {
                        Text("Value")
                        Spacer()
                        TextField("0", text: $value)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("Unit")
                        Spacer()
                        TextField("e.g. mg/dL", text: $unit)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Reference Range (optional)") {
                    HStack {
                        Text("Low")
                        Spacer()
                        TextField("—", text: $referenceLow)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("High")
                        Spacer()
                        TextField("—", text: $referenceHigh)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }
            .navigationTitle("Add Lab Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var testName: String {
        selectedTest?.name ?? customName.trimmingCharacters(in: .whitespaces)
    }

    private var isValid: Bool {
        !testName.isEmpty && Double(value) != nil
    }

    private func save() {
        let result = LabResult(
            testName: testName,
            value: Double(value) ?? 0,
            unit: unit,
            referenceLow: Double(referenceLow),
            referenceHigh: Double(referenceHigh),
            date: date
        )
        context.insert(result)
        dismiss()
    }
}
