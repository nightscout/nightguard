//
//  CareView.swift
//  nightguard
//
//  SwiftUI version of CareViewController
//

import SwiftUI

struct CareView: View {
    @Binding var selectedTab: Int

    @State private var selectedReason = UserDefaultsRepository.temporaryTargetReason.value
    @State private var selectedDuration = UserDefaultsRepository.temporaryTargetDuration.value
    @State private var selectedTargetValue = UserDefaultsRepository.temporaryTargetAmount.value
    @State private var selectedCarbs = UserDefaultsRepository.carbs.value

    @State private var showSetTargetConfirmation = false
    @State private var showDeleteTargetConfirmation = false
    @State private var showAddCarbsConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let reasons = ["Activity", "Too High", "Too Low", "Meal Soon"]
    private let durations = [30, 60, 90, 120, 180, 360, 480, 600, 720]
    private let targetValues = [72, 80, 100, 120, 145, 160]
    private let carbsOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]

    var body: some View {
        NavigationView {
            Form {
                // Set a new Temporary Target section
                Section(header: Text("Set a new Temporary Target")) {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(reasons, id: \.self) { reason in
                            Text(NSLocalizedString(reason, comment: "")).tag(reason)
                        }
                    }
                    .onChange(of: selectedReason) { newValue in
                        UserDefaultsRepository.temporaryTargetReason.value = newValue
                        restoreDefaultTargetValue(for: newValue)
                        restoreDefaultDuration(for: newValue)
                    }

                    Picker("Duration", selection: $selectedDuration) {
                        ForEach(durations, id: \.self) { duration in
                            Text(durationLabel(for: duration)).tag(duration)
                        }
                    }
                    .onChange(of: selectedDuration) { newValue in
                        UserDefaultsRepository.temporaryTargetDuration.value = newValue
                        storeNewDefault(duration: newValue)
                    }

                    Picker("Target Value", selection: $selectedTargetValue) {
                        ForEach(targetValues, id: \.self) { value in
                            Text(UnitsConverter.mgdlToDisplayUnits(String(describing: value))).tag(value)
                        }
                    }
                    .onChange(of: selectedTargetValue) { newValue in
                        UserDefaultsRepository.temporaryTargetAmount.value = newValue
                        storeNewDefault(value: newValue)
                    }

                    Button(action: {
                        showSetTargetConfirmation = true
                    }) {
                        Text("Set Target")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                    }
                }

                // Delete an active Temporary Target section
                Section(header: Text("Delete an active Temporary Target")) {
                    Button(action: {
                        showDeleteTargetConfirmation = true
                    }) {
                        Text("Delete Temporary Target")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                    }
                }

                // Enter consumed Carbs section
                Section(header: Text("Enter consumed Carbs")) {
                    Picker("Gramms [g]", selection: $selectedCarbs) {
                        ForEach(carbsOptions, id: \.self) { carbs in
                            Text("\(carbs)g").tag(carbs)
                        }
                    }
                    .onChange(of: selectedCarbs) { newValue in
                        UserDefaultsRepository.carbs.value = newValue
                    }

                    Button(action: {
                        showAddCarbsConfirmation = true
                    }) {
                        Text("Add Carbs")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Care")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedReason = UserDefaultsRepository.temporaryTargetReason.value
                selectedDuration = UserDefaultsRepository.temporaryTargetDuration.value
                selectedTargetValue = UserDefaultsRepository.temporaryTargetAmount.value
                selectedCarbs = UserDefaultsRepository.carbs.value
            }
            .alert("Set Target '\(selectedReason)'?", isPresented: $showSetTargetConfirmation) {
                Button("Accept", role: .none) {
                    setTemporaryTarget()
                }
                Button("Decline", role: .cancel) {}
            } message: {
                Text("Do you want to set a temporary target for \(selectedDuration) minutes?")
            }
            .alert("Cancel Target", isPresented: $showDeleteTargetConfirmation) {
                Button("Accept", role: .destructive) {
                    deleteTemporaryTarget()
                }
                Button("Decline", role: .cancel) {}
            } message: {
                Text("Do you want to cancel an active temporary target?")
            }
            .alert("Add Carbs", isPresented: $showAddCarbsConfirmation) {
                Button("Accept", role: .none) {
                    addCarbs()
                }
                Button("Decline", role: .cancel) {}
            } message: {
                Text("Do you want to enter \(selectedCarbs)g of consumed carbs?")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Helper Methods

    private func durationLabel(for minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) " + NSLocalizedString("minutes", comment: "Minutes TT Unit")
        } else if minutes == 60 {
            return "1 " + NSLocalizedString("hour", comment: "Hour TT Unit")
        } else if minutes == 90 {
            return "1.5 " + NSLocalizedString("hours", comment: "Hour TT Unit")
        } else {
            return "\(minutes / 60) " + NSLocalizedString("hours", comment: "Hour TT Unit")
        }
    }

    private func restoreDefaultTargetValue(for reason: String) {
        switch reason {
        case "Activity":
            selectedTargetValue = UserDefaultsRepository.temporaryTargetActivityDefaultAmount.value
        case "Too High":
            selectedTargetValue = UserDefaultsRepository.temporaryTargetTooHighDefaultAmount.value
        case "Too Low":
            selectedTargetValue = UserDefaultsRepository.temporaryTargetTooLowDefaultAmount.value
        default:
            selectedTargetValue = UserDefaultsRepository.temporaryTargetMealSoonDefaultAmount.value
        }
    }

    private func restoreDefaultDuration(for reason: String) {
        switch reason {
        case "Activity":
            selectedDuration = UserDefaultsRepository.temporaryTargetActivityDefaultDuration.value
        case "Too High":
            selectedDuration = UserDefaultsRepository.temporaryTargetTooHighDefaultDuration.value
        case "Too Low":
            selectedDuration = UserDefaultsRepository.temporaryTargetTooLowDefaultDuration.value
        default:
            selectedDuration = UserDefaultsRepository.temporaryTargetMealSoonDefaultDuration.value
        }
    }

    private func storeNewDefault(duration: Int) {
        switch selectedReason {
        case "Activity":
            UserDefaultsRepository.temporaryTargetActivityDefaultDuration.value = duration
        case "Too High":
            UserDefaultsRepository.temporaryTargetTooHighDefaultDuration.value = duration
        case "Too Low":
            UserDefaultsRepository.temporaryTargetTooLowDefaultDuration.value = duration
        default:
            UserDefaultsRepository.temporaryTargetMealSoonDefaultDuration.value = duration
        }
    }

    private func storeNewDefault(value: Int) {
        switch selectedReason {
        case "Activity":
            UserDefaultsRepository.temporaryTargetActivityDefaultAmount.value = value
        case "Too High":
            UserDefaultsRepository.temporaryTargetTooHighDefaultAmount.value = value
        case "Too Low":
            UserDefaultsRepository.temporaryTargetTooLowDefaultAmount.value = value
        default:
            UserDefaultsRepository.temporaryTargetMealSoonDefaultAmount.value = value
        }
    }

    private func setTemporaryTarget() {
        playSuccessFeedback()
        NightscoutService.singleton.createTemporaryTarget(
            reason: selectedReason,
            target: selectedTargetValue,
            durationInMinutes: selectedDuration
        ) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                // Switch to main tab
                selectedTab = 0
            }
        }
    }

    private func deleteTemporaryTarget() {
        playSuccessFeedback()
        NightscoutService.singleton.deleteTemporaryTarget { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                // Switch to main tab
                selectedTab = 0
            }
        }
    }

    private func addCarbs() {
        playSuccessFeedback()
        NightscoutService.singleton.createCarbsCorrection(carbs: selectedCarbs) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                // Switch to main tab
                selectedTab = 0
            }
        }
    }

    private func playSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    CareView(selectedTab: .constant(2))
}
