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
    @ObservedObject private var alarmService = AlarmNotificationService.singleton
    @ObservedObject var purchaseManager = PurchaseManager.shared

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

                // Alert Notifications section
                Section(
                    footer: Text(NSLocalizedString("DurationNotificationDescription", comment: "Footer for Duration notifications"))
                        .font(.footnote)
                ) {
                    HStack {
                        Toggle(NSLocalizedString("Duration Notifications", comment: "Label for Duration Notifications toggle"), isOn: Binding(
                            get: { alarmService.publishedEnabled },
                            set: { alarmService.enabled = $0 }
                        ))
                        .disabled(!purchaseManager.isProAccessAvailable)
                        
                        if purchaseManager.isProAccessAvailable {
                            Text("PRO")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        } else {
                            Text("PRO")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray)
                                .cornerRadius(4)
                        }
                    }
                    
                    if !purchaseManager.isProAccessAvailable {
                        Button(action: {
                            purchaseManager.buyProVersion()
                        }) {
                            Text(NSLocalizedString("Unlock Pro Version", comment: "Unlock Pro Version Button"))
                        }
                    }
                }

                AgeAlertsView()
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
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Helper Methods

    private func saveCannulaChangeDate() {
        NightscoutService.singleton.createCannulaChangeTreatment(changeDate: cannulaChangeDate) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            } else {
                NightscoutDataRepository.singleton.storeCannulaChangeTime(cannulaChangeTime: cannulaChangeDate)
                AlarmNotificationService.singleton.scheduleCannulaNotification(changeDate: cannulaChangeDate)
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
                AlarmNotificationService.singleton.scheduleSensorNotification(changeDate: sensorChangeDate)
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
                AlarmNotificationService.singleton.scheduleBatteryNotification(changeDate: batteryChangeDate)
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

// MARK: - Age Alerts View
struct AgeAlertsView: View {
    // Sensor values (in days for display)
    @State private var sensorWarningDays: Float = 0
    @State private var sensorCriticalDays: Float = 0

    // Cannula values (split into days and hours for display)
    @State private var cannulaWarningDays: Float = 0
    @State private var cannulaWarningHours: Float = 0
    @State private var cannulaCriticalDays: Float = 0
    @State private var cannulaCriticalHours: Float = 0

    // Battery values (in days for display)
    @State private var batteryWarningDays: Float = 0
    @State private var batteryCriticalDays: Float = 0

    // Helper functions for cannula
    private func saveCannulaWarning() {
        let totalHours = Int(cannulaWarningDays * 24 + cannulaWarningHours)
        guard totalHours < UserDefaultsRepository.cannulaAgeHoursUntilCritical.value else {
            // Reset to previous value if >= critical
            loadCannulaWarning()
            return
        }
        UserDefaultsRepository.cannulaAgeHoursUntilWarning.value = totalHours
    }

    private func saveCannulaCritical() {
        let totalHours = Int(cannulaCriticalDays * 24 + cannulaCriticalHours)
        guard totalHours > UserDefaultsRepository.cannulaAgeHoursUntilWarning.value else {
            // Reset to previous value if <= warning
            loadCannulaCritical()
            return
        }
        UserDefaultsRepository.cannulaAgeHoursUntilCritical.value = totalHours
        AlarmNotificationService.singleton.scheduleCannulaNotification(changeDate: NightscoutCacheService.singleton.getCannulaChangeTime())
    }

    private func loadCannulaWarning() {
        let totalHours = UserDefaultsRepository.cannulaAgeHoursUntilWarning.value
        cannulaWarningDays = Float(totalHours / 24)
        cannulaWarningHours = Float(totalHours % 24)
    }

    private func loadCannulaCritical() {
        let totalHours = UserDefaultsRepository.cannulaAgeHoursUntilCritical.value
        cannulaCriticalDays = Float(totalHours / 24)
        cannulaCriticalHours = Float(totalHours % 24)
    }

    var body: some View {
        Group {
            // Sensor Age Section
            Section(
                header: Text(NSLocalizedString("Sensor Age", comment: "Sensor Age section header")),
                footer: Text(NSLocalizedString("Set thresholds for sensor age alerts. Warning turns the label yellow, Critical turns it red.", comment: "Footer for sensor age alerts"))
                    .font(.footnote)
            ) {
                // Warning
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Warning", comment: "Warning threshold label"))
                        Spacer()
                        Stepper(
                            "\(sensorWarningDays.cleanValue) \(NSLocalizedString("days", comment: "Unit: days"))",
                            value: $sensorWarningDays,
                            in: 1...30,
                            step: 1
                        )
                        .onChange(of: sensorWarningDays) { newValue in
                            let hours = Int(newValue * 24)
                            guard hours < UserDefaultsRepository.sensorAgeHoursUntilCritical.value else {
                                // Reset to previous value if >= critical
                                sensorWarningDays = Float(UserDefaultsRepository.sensorAgeHoursUntilWarning.value) / 24.0
                                return
                            }
                            UserDefaultsRepository.sensorAgeHoursUntilWarning.value = hours
                        }
                    }
                }

                // Critical
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Critical", comment: "Critical threshold label"))
                        Spacer()
                        Stepper(
                            "\(sensorCriticalDays.cleanValue) \(NSLocalizedString("days", comment: "Unit: days"))",
                            value: $sensorCriticalDays,
                            in: 1...30,
                            step: 1
                        )
                        .onChange(of: sensorCriticalDays) { newValue in
                            let hours = Int(newValue * 24)
                            guard hours > UserDefaultsRepository.sensorAgeHoursUntilWarning.value else {
                                // Reset to previous value if <= warning
                                sensorCriticalDays = Float(UserDefaultsRepository.sensorAgeHoursUntilCritical.value) / 24.0
                                return
                            }
                            UserDefaultsRepository.sensorAgeHoursUntilCritical.value = hours
                            AlarmNotificationService.singleton.scheduleSensorNotification(changeDate: NightscoutCacheService.singleton.getSensorChangeTime())
                        }
                    }
                }
            }

            // Battery Age Section
            Section(
                header: Text(NSLocalizedString("Battery Age", comment: "Battery Age section header")),
                footer: Text(NSLocalizedString("Set thresholds for pump battery age alerts. Warning turns the label yellow, Critical turns it red.", comment: "Footer for battery age alerts"))
                    .font(.footnote)
            ) {
                // Warning
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Warning", comment: "Warning threshold label"))
                        Spacer()
                        Stepper(
                            "\(batteryWarningDays.cleanValue) \(NSLocalizedString("days", comment: "Unit: days"))",
                            value: $batteryWarningDays,
                            in: 1...30,
                            step: 1
                        )
                        .onChange(of: batteryWarningDays) { newValue in
                            let hours = Int(newValue * 24)
                            guard hours < UserDefaultsRepository.batteryAgeHoursUntilCritical.value else {
                                batteryWarningDays = Float(UserDefaultsRepository.batteryAgeHoursUntilWarning.value) / 24.0
                                return
                            }
                            UserDefaultsRepository.batteryAgeHoursUntilWarning.value = hours
                        }
                    }
                }

                // Critical
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Critical", comment: "Critical threshold label"))
                        Spacer()
                        Stepper(
                            "\(batteryCriticalDays.cleanValue) \(NSLocalizedString("days", comment: "Unit: days"))",
                            value: $batteryCriticalDays,
                            in: 1...30,
                            step: 1
                        )
                        .onChange(of: batteryCriticalDays) { newValue in
                            let hours = Int(newValue * 24)
                            guard hours > UserDefaultsRepository.batteryAgeHoursUntilWarning.value else {
                                batteryCriticalDays = Float(UserDefaultsRepository.batteryAgeHoursUntilCritical.value) / 24.0
                                return
                            }
                            UserDefaultsRepository.batteryAgeHoursUntilCritical.value = hours
                            AlarmNotificationService.singleton.scheduleBatteryNotification(changeDate: NightscoutCacheService.singleton.getPumpBatteryChangeTime())
                        }
                    }
                }
            }
            
            // Cannula Age Section
            Section(
                header: Text(NSLocalizedString("Cannula Age", comment: "Cannula Age section header")),
                footer: Text(NSLocalizedString("Set thresholds for cannula age alerts. Warning turns the label yellow, Critical turns it red.", comment: "Footer for cannula age alerts"))
                    .font(.footnote)
            ) {
                // Warning
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("Warning", comment: "Warning threshold label"))
                        .font(.headline)

                    HStack(spacing: 12) {
                        // Days
                        HStack(spacing: 4) {
                            Text(NSLocalizedString("Days", comment: "Days label"))
                                .foregroundColor(.secondary)
                            Stepper(
                                value: $cannulaWarningDays,
                                in: 0...10,
                                step: 1
                            ) {
                                Text("\(Int(cannulaWarningDays))")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minWidth: 30, alignment: .trailing)
                            }
                            .onChange(of: cannulaWarningDays) { _ in
                                saveCannulaWarning()
                            }
                        }

                        Spacer()

                        // Hours
                        HStack(spacing: 4) {
                            Text(NSLocalizedString("Hours", comment: "Hours label"))
                                .foregroundColor(.secondary)
                            Stepper(
                                value: $cannulaWarningHours,
                                in: 0...23,
                                step: 1
                            ) {
                                Text("\(Int(cannulaWarningHours))")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minWidth: 30, alignment: .trailing)
                            }
                            .onChange(of: cannulaWarningHours) { _ in
                                saveCannulaWarning()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                // Critical
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("Critical", comment: "Critical threshold label"))
                        .font(.headline)

                    HStack(spacing: 12) {
                        // Days
                        HStack(spacing: 4) {
                            Text(NSLocalizedString("Days", comment: "Days label"))
                                .foregroundColor(.secondary)
                            Stepper(
                                value: $cannulaCriticalDays,
                                in: 0...10,
                                step: 1
                            ) {
                                Text("\(Int(cannulaCriticalDays))")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minWidth: 30, alignment: .trailing)
                            }
                            .onChange(of: cannulaCriticalDays) { _ in
                                saveCannulaCritical()
                            }
                        }

                        Spacer()

                        // Hours
                        HStack(spacing: 4) {
                            Text(NSLocalizedString("Hours", comment: "Hours label"))
                                .foregroundColor(.secondary)
                            Stepper(
                                value: $cannulaCriticalHours,
                                in: 0...23,
                                step: 1
                            ) {
                                Text("\(Int(cannulaCriticalHours))")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minWidth: 30, alignment: .trailing)
                            }
                            .onChange(of: cannulaCriticalHours) { _ in
                                saveCannulaCritical()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            // Load current values - convert sensor and battery to days, split cannula into days and hours
            sensorWarningDays = Float(UserDefaultsRepository.sensorAgeHoursUntilWarning.value) / 24.0
            sensorCriticalDays = Float(UserDefaultsRepository.sensorAgeHoursUntilCritical.value) / 24.0
            loadCannulaWarning()
            loadCannulaCritical()
            batteryWarningDays = Float(UserDefaultsRepository.batteryAgeHoursUntilWarning.value) / 24.0
            batteryCriticalDays = Float(UserDefaultsRepository.batteryAgeHoursUntilCritical.value) / 24.0
        }
    }
}
