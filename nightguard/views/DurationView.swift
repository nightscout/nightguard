//
//  DurationView.swift
//  nightguard
//
//  SwiftUI version of DurationViewController
//

import SwiftUI

struct DurationView: View {
    @Binding var selectedTab: Int

    @State private var cannulaChangeDate = NightscoutCacheService.singleton.getCannulaChangeTime()
    @State private var sensorChangeDate = NightscoutCacheService.singleton.getSensorChangeTime()
    @State private var batteryChangeDate = NightscoutCacheService.singleton.getPumpBatteryChangeTime()

    @State private var showCannulaConfirmation = false
    @State private var showSensorConfirmation = false
    @State private var showBatteryConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // Cannula section
                Section(
                    header: Text(NSLocalizedString("Cannula", comment: "Cannula Row Header")),
                    footer: Text(NSLocalizedString("Set the time when you changed your cannula. This will be displayed on the main screen as CAGE. Keep in mind that you just can reduce this date.", comment: "Footer for Cannula Change Date"))
                        .font(.footnote)
                ) {
                    HStack {
                        Text(NSLocalizedString("Cannula change date", comment: "Label for Cannula Change Time"))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $cannulaChangeDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    HStack {
                        Spacer()
                        Button(NSLocalizedString("Reset", comment: "Button to reset the new Cannula Change Date")) {
                            cannulaChangeDate = Date()
                        }
                        .foregroundColor(.white)
                        Spacer()
                        Button(NSLocalizedString("Save", comment: "Button to activate the new Cannula Change Date")) {
                            showCannulaConfirmation = true
                        }
                        .foregroundColor(.white)
                        Spacer()
                    }
                }

                // Sensor section
                Section(
                    header: Text(NSLocalizedString("Sensor", comment: "Sensor Row Header")),
                    footer: Text(NSLocalizedString("Set the time when you changed your sensor. This will be displayed on the main screen as SAGE. Keep in mind that you just can reduce this date.", comment: "Footer for Sensor"))
                        .font(.footnote)
                ) {
                    HStack {
                        Text(NSLocalizedString("Sensor change date", comment: "Label for Sensor Change Time"))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $sensorChangeDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    HStack {
                        Spacer()
                        Button(NSLocalizedString("Reset", comment: "Button to reset the new Sensor Change Date")) {
                            sensorChangeDate = Date()
                        }
                        .foregroundColor(.white)
                        Spacer()
                        Button(NSLocalizedString("Save", comment: "Button to activate the new Sensor Change Date")) {
                            showSensorConfirmation = true
                        }
                        .foregroundColor(.white)
                        Spacer()
                    }
                }

                // Battery section
                Section(
                    header: Text(NSLocalizedString("Battery", comment: "Battery Row Header")),
                    footer: Text(NSLocalizedString("Set the time when you changed your pump battery. This will be displayed on the main screen as BAGE. Keep in mind that you just can reduce this date.", comment: "Footer for Battery"))
                        .font(.footnote)
                ) {
                    HStack {
                        Text(NSLocalizedString("Battery change date", comment: "Label for Battery Change Time"))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $batteryChangeDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    HStack {
                        Spacer()
                        Button(NSLocalizedString("Reset", comment: "Button to reset the new Battery Change Date")) {
                            batteryChangeDate = Date()
                        }
                        .foregroundColor(.white)
                        Spacer()
                        Button(NSLocalizedString("Save", comment: "Button to activate the new Battery Change Date")) {
                            showBatteryConfirmation = true
                        }
                        .foregroundColor(.white)
                        Spacer()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Duration", comment: "Duration tab"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                cannulaChangeDate = NightscoutCacheService.singleton.getCannulaChangeTime()
                sensorChangeDate = NightscoutCacheService.singleton.getSensorChangeTime()
                batteryChangeDate = NightscoutCacheService.singleton.getPumpBatteryChangeTime()
            }
            .alert(NSLocalizedString("Modify Cannula Change Date", comment: "Modify Cannula Change Date Popup Title"), isPresented: $showCannulaConfirmation) {
                Button(NSLocalizedString("Accept", comment: "Popup Accept-Button")) {
                    saveCannulaChangeDate()
                }
                Button(NSLocalizedString("Decline", comment: "Popup Decline-Button"), role: .cancel) {}
            } message: {
                Text(String(format: NSLocalizedString("Do you want to modify the change date to %@", comment: "Cancel Target Popup Text"), cannulaChangeDate.toDateTimeString()))
            }
            .alert(NSLocalizedString("Modify Sensor Change Date", comment: "Modify Sensor Change Date Popup Title"), isPresented: $showSensorConfirmation) {
                Button(NSLocalizedString("Accept", comment: "Popup Accept-Button")) {
                    saveSensorChangeDate()
                }
                Button(NSLocalizedString("Decline", comment: "Popup Decline-Button"), role: .cancel) {}
            } message: {
                Text(String(format: NSLocalizedString("Do you want to modify the change date to %@", comment: "Cancel Target Popup Text"), sensorChangeDate.toDateTimeString()))
            }
            .alert(NSLocalizedString("Modify Battery Change Date", comment: "Modify Battery Change Date Popup Title"), isPresented: $showBatteryConfirmation) {
                Button(NSLocalizedString("Accept", comment: "Popup Accept-Button")) {
                    saveBatteryChangeDate()
                }
                Button(NSLocalizedString("Decline", comment: "Popup Decline-Button"), role: .cancel) {}
            } message: {
                Text(String(format: NSLocalizedString("Do you want to modify the change date to %@", comment: "Cancel Target Popup Text"), batteryChangeDate.toDateTimeString()))
            }
            .alert(NSLocalizedString("Error", comment: "Popup Error Message Title"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("OK", comment: "Popup OK-Button"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Helper Methods

    private func saveCannulaChangeDate() {
        NightscoutService.singleton.createCannulaChangeTreatment(changeDate: cannulaChangeDate) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                NightscoutDataRepository.singleton.storeCannulaChangeTime(cannulaChangeTime: cannulaChangeDate)
                playSuccessFeedback()
                selectedTab = 0
            }
        }
    }

    private func saveSensorChangeDate() {
        NightscoutService.singleton.createSensorChangeTreatment(changeDate: sensorChangeDate) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                NightscoutDataRepository.singleton.storeSensorChangeTime(sensorChangeTime: sensorChangeDate)
                playSuccessFeedback()
                selectedTab = 0
            }
        }
    }

    private func saveBatteryChangeDate() {
        NightscoutService.singleton.createBatteryChangeTreatment(changeDate: batteryChangeDate) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                NightscoutDataRepository.singleton.storeBatteryChangeTime(batteryChangeTime: batteryChangeDate)
                playSuccessFeedback()
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
    DurationView(selectedTab: .constant(3))
}
