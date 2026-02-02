//
//  AgeAlertsView.swift
//  nightguard
//
//  Created by Gemini CLI.
//

import SwiftUI

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

    // Reservoir values
    @State private var reservoirWarning: Float = 0
    @State private var reservoirCritical: Float = 0

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
        Form {
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
            
            // Reservoir Section
            Section(
                header: Text(NSLocalizedString("Reservoir", comment: "Reservoir section header")),
                footer: Text(NSLocalizedString("Set thresholds for reservoir alerts. Warning turns the label yellow, Critical turns it red.", comment: "Footer for reservoir alerts"))
                    .font(.footnote)
            ) {
                // Warning
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Warning", comment: "Warning threshold label"))
                        Spacer()
                        Stepper(
                            String(format: NSLocalizedString("%d units", comment: "Reservoir units"), Int(reservoirWarning)),
                            value: $reservoirWarning,
                            in: 0...300,
                            step: 5
                        )
                        .onChange(of: reservoirWarning) { newValue in
                            let value = Int(newValue)
                            guard value > UserDefaultsRepository.reservoirUnitsCritical.value else {
                                reservoirWarning = Float(UserDefaultsRepository.reservoirUnitsWarning.value)
                                return
                            }
                            UserDefaultsRepository.reservoirUnitsWarning.value = value
                        }
                    }
                }

                // Critical
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Critical", comment: "Critical threshold label"))
                        Spacer()
                        Stepper(
                            String(format: NSLocalizedString("%d units", comment: "Reservoir units"), Int(reservoirCritical)),
                            value: $reservoirCritical,
                            in: 0...300,
                            step: 5
                        )
                        .onChange(of: reservoirCritical) { newValue in
                            let value = Int(newValue)
                            guard value < UserDefaultsRepository.reservoirUnitsWarning.value else {
                                reservoirCritical = Float(UserDefaultsRepository.reservoirUnitsCritical.value)
                                return
                            }
                            UserDefaultsRepository.reservoirUnitsCritical.value = value
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("Disposables Age Warnings", comment: "Disposables Age Warnings menu item"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load current values - convert sensor and battery to days, split cannula into days and hours
            sensorWarningDays = Float(UserDefaultsRepository.sensorAgeHoursUntilWarning.value) / 24.0
            sensorCriticalDays = Float(UserDefaultsRepository.sensorAgeHoursUntilCritical.value) / 24.0
            loadCannulaWarning()
            loadCannulaCritical()
            batteryWarningDays = Float(UserDefaultsRepository.batteryAgeHoursUntilWarning.value) / 24.0
            batteryCriticalDays = Float(UserDefaultsRepository.batteryAgeHoursUntilCritical.value) / 24.0
            reservoirWarning = Float(UserDefaultsRepository.reservoirUnitsWarning.value)
            reservoirCritical = Float(UserDefaultsRepository.reservoirUnitsCritical.value)
        }
    }
}
