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
                    header: Text("Cannula"),
                    footer: Text("Set the time when you changed your cannula. This will be displayed on the main screen as CAGE. Keep in mind that you just can reduce this date.")
                        .font(.footnote)
                ) {
                    HStack {
                        Text("Cannula change date")
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
                        Button("Reset") {
                            cannulaChangeDate = Date()
                        }
                        .foregroundColor(.white)
                        Spacer()
                        Button("Save") {
                            showCannulaConfirmation = true
                        }
                        .foregroundColor(.white)
                        Spacer()
                    }
                }

                // Sensor section
                Section(
                    header: Text("Sensor"),
                    footer: Text("Set the time when you changed your sensor. This will be displayed on the main screen as SAGE. Keep in mind that you just can reduce this date.")
                        .font(.footnote)
                ) {
                    HStack {
                        Text("Sensor change date")
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
                        Button("Reset") {
                            sensorChangeDate = Date()
                        }
                        .foregroundColor(.white)
                        Spacer()
                        Button("Save") {
                            showSensorConfirmation = true
                        }
                        .foregroundColor(.white)
                        Spacer()
                    }
                }

                // Battery section
                Section(
                    header: Text("Battery"),
                    footer: Text("Set the time when you changed your pump battery. This will be displayed on the main screen as BAGE. Keep in mind that you just can reduce this date.")
                        .font(.footnote)
                ) {
                    HStack {
                        Text("Battery change date")
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
                        Button("Reset") {
                            batteryChangeDate = Date()
                        }
                        .foregroundColor(.white)
                        Spacer()
                        Button("Save") {
                            showBatteryConfirmation = true
                        }
                        .foregroundColor(.white)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                cannulaChangeDate = NightscoutCacheService.singleton.getCannulaChangeTime()
                sensorChangeDate = NightscoutCacheService.singleton.getSensorChangeTime()
                batteryChangeDate = NightscoutCacheService.singleton.getPumpBatteryChangeTime()
            }
            .alert("Modify Cannula Change Date", isPresented: $showCannulaConfirmation) {
                Button("Accept", role: .none) {
                    saveCannulaChangeDate()
                }
                Button("Decline", role: .cancel) {}
            } message: {
                Text("Do you want to modify the change date to \(cannulaChangeDate.toDateTimeString())?")
            }
            .alert("Modify Sensor Change Date", isPresented: $showSensorConfirmation) {
                Button("Accept", role: .none) {
                    saveSensorChangeDate()
                }
                Button("Decline", role: .cancel) {}
            } message: {
                Text("Do you want to modify the change date to \(sensorChangeDate.toDateTimeString())?")
            }
            .alert("Modify Battery Change Date", isPresented: $showBatteryConfirmation) {
                Button("Accept", role: .none) {
                    saveBatteryChangeDate()
                }
                Button("Decline", role: .cancel) {}
            } message: {
                Text("Do you want to modify the change date to \(batteryChangeDate.toDateTimeString())?")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
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
