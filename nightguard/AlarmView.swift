//
//  AlarmView.swift
//  nightguard
//
//  SwiftUI version of AlarmViewController
//

import SwiftUI

struct AlarmView: View {
    @State private var disableAllAlerts = AlarmRule.areAlertsGenerallyDisabled.value
    @State private var highBGValue: Float = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfAboveValue.value)) ?? 180
    @State private var lowBGValue: Float = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfBelowValue.value)) ?? 80
    @State private var smartSnoozeEnabled = AlarmRule.isSmartSnoozeEnabled.value
    @State private var alertNotifications = AlarmNotificationService.singleton.enabled
    @State private var showDisableAlertsConfirmation = false
    @State private var showInvalidChangeAlert = false
    @State private var invalidChangeMessage = ""

    private let maxAlertAbove: Float = 280
    private let minAlertAbove: Float = 80
    private let maxAlertBelow: Float = 200
    private let minAlertBelow: Float = 50

    var body: some View {
        Form {
            // Disable all alerts section
            Section(
                footer: Text("Deactivate all alerts. This is NOT recommended. You will get no alarms or notifications at all anymore!")
                    .font(.footnote)
            ) {
                Toggle("Disable all alerts", isOn: $disableAllAlerts)
                    .onChange(of: disableAllAlerts) { newValue in
                        if !newValue {
                            AlarmRule.areAlertsGenerallyDisabled.value = newValue
                        } else {
                            showDisableAlertsConfirmation = true
                        }
                    }
            }

            if !disableAllAlerts {
                // High BG Alert section
                Section(
                    header: Text("High BG Alert"),
                    footer: Text("Alerts when the blood glucose raises above this value.")
                        .font(.footnote)
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("High Alert")
                            Spacer()
                            Text("\(Int(highBGValue)) \(UserDefaultsRepository.units.value.description)")
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $highBGValue,
                            in: Float(UnitsConverter.mgdlToDisplayUnits(minAlertAbove))...Float(UnitsConverter.mgdlToDisplayUnits(maxAlertAbove)),
                            step: 1
                        )
                        .onChange(of: highBGValue) { newValue in
                            let mgdlValue = UnitsConverter.displayValueToMgdl(newValue)
                            guard mgdlValue > UserDefaultsRepository.lowerBound.value else {
                                invalidChangeMessage = "High BG value should be above low BG value!"
                                showInvalidChangeAlert = true
                                highBGValue = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfAboveValue.value)) ?? 180
                                return
                            }
                            UserDefaultsRepository.upperBound.value = mgdlValue
                        }
                    }
                }

                // Low BG Alert section
                Section(
                    header: Text("Low BG Alert"),
                    footer: Text("Alerts when the blood glucose drops below this value.")
                        .font(.footnote)
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Low Alert")
                            Spacer()
                            Text("\(Int(lowBGValue)) \(UserDefaultsRepository.units.value.description)")
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $lowBGValue,
                            in: Float(UnitsConverter.mgdlToDisplayUnits(minAlertBelow))...Float(UnitsConverter.mgdlToDisplayUnits(maxAlertBelow)),
                            step: 1
                        )
                        .onChange(of: lowBGValue) { newValue in
                            let mgdlValue = UnitsConverter.displayValueToMgdl(newValue)
                            guard mgdlValue < UserDefaultsRepository.upperBound.value else {
                                invalidChangeMessage = "Low BG value should be below low BG value!"
                                showInvalidChangeAlert = true
                                lowBGValue = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfBelowValue.value)) ?? 80
                                return
                            }
                            UserDefaultsRepository.lowerBound.value = mgdlValue
                        }
                    }
                }

                // Other Alerts section
                Section(header: Text("Other Alerts")) {
                    if #available(iOS 14.0, *) {
                        NavigationLink(destination: AlarmSoundViewRepresentable()) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Alarm Sound")
                                Text("Define your own Alarm Sound by uploading an mp3 file from your iCloud account.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: MissedReadingsViewRepresentable()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Missed Readings")
                            Text(getMissedReadingsDetail())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: FastRiseDropViewRepresentable()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fast Rise/Drop")
                            Text(getFastRiseDropDetail())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: PersistentHighViewRepresentable()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Persistent High")
                            Text(getPersistentHighDetail())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: LowPredictionViewRepresentable()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Low Prediction")
                            Text(getLowPredictionDetail())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Smart Snooze section
                Section(
                    footer: Text("Snooze (do not alert) when values are high or low but the trend is going in the right direction.")
                        .font(.footnote)
                ) {
                    Toggle("Smart Snooze", isOn: $smartSnoozeEnabled)
                        .onChange(of: smartSnoozeEnabled) { newValue in
                            AlarmRule.isSmartSnoozeEnabled.value = newValue
                        }
                }

                // Alert Notifications section
                Section(
                    footer: Text(NSLocalizedString("AlarmNotificationDescription", comment: "Footer for Alert notifications"))
                        .font(.footnote)
                ) {
                    Toggle("Alert Notifications", isOn: $alertNotifications)
                        .onChange(of: alertNotifications) { newValue in
                            AlarmNotificationService.singleton.enabled = newValue
                        }
                }

                // Additional Settings section
                Section {
                    NavigationLink(destination: AlertVolumeViewRepresentable()) {
                        Text("Alert Volume")
                    }

                    NavigationLink(destination: SnoozeActionsViewRepresentable()) {
                        Text("Snoozing Actions")
                    }
                }
            }
        }
        .navigationTitle("Alarms")
        .navigationBarTitleDisplayMode(.inline)
        .alert("ARE YOU SURE?", isPresented: $showDisableAlertsConfirmation) {
            Button("No", role: .cancel) {
                disableAllAlerts = false
            }
            Button("Yes", role: .destructive) {
                AlarmRule.areAlertsGenerallyDisabled.value = true
            }
        } message: {
            Text("It is not recommended to disable all alerts! Do you really want to disable all alerts?")
        }
        .alert("Invalid change", isPresented: $showInvalidChangeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(invalidChangeMessage)
        }
    }

    // MARK: - Helper Methods

    private func getMissedReadingsDetail() -> String {
        if AlarmRule.noDataAlarmEnabled.value {
            return String(format: NSLocalizedString("Alerts when no data for more than %d minutes.", comment: ""), AlarmRule.minutesWithoutValues.value)
        } else {
            return NSLocalizedString("Off", comment: "")
        }
    }

    private func getFastRiseDropDetail() -> String {
        if AlarmRule.isEdgeDetectionAlarmEnabled.value {
            let deltaInMgdl = AlarmRule.deltaAmount.value
            let delta = UnitsConverter.mgdlToDisplayUnits("\(deltaInMgdl)")
            let units = UserDefaultsRepository.units.value.description
            let consecutiveValue = AlarmRule.numberOfConsecutiveValues.value

            return String(format: NSLocalizedString(
                "Alerts when BG values are rising or dropping with %@ %@, considering the last %d consecutive readings.",
                comment: ""), delta, units, consecutiveValue)
        } else {
            return NSLocalizedString("Off", comment: "")
        }
    }

    private func getPersistentHighDetail() -> String {
        let urgentHighInMgdl = AlarmRule.persistentHighUpperBound.value
        let urgentHigh = UnitsConverter.mgdlToDisplayUnits("\(urgentHighInMgdl)")
        let units = UserDefaultsRepository.units.value.description
        let urgentHighWithUnits = "\(urgentHigh) \(units)"

        if AlarmRule.isPersistentHighEnabled.value {
            return String(format: NSLocalizedString(
                "Alerts when BG remains high for more than %d minutes or exceeds the urgent high value %@.",
                comment: ""), AlarmRule.persistentHighMinutes.value, urgentHighWithUnits)
        } else {
            return NSLocalizedString("Off", comment: "")
        }
    }

    private func getLowPredictionDetail() -> String {
        if AlarmRule.isLowPredictionEnabled.value {
            return String(format: NSLocalizedString("Alerts when a low BG value is predicted in less than %d minutes.", comment: ""), AlarmRule.minutesToPredictLow.value)
        } else {
            return NSLocalizedString("Off", comment: "")
        }
    }
}

// MARK: - UIKit View Controller Wrappers

struct AlarmSoundViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AlarmSoundViewController {
        return AlarmSoundViewController()
    }

    func updateUIViewController(_ uiViewController: AlarmSoundViewController, context: Context) {
        // No updates needed
    }
}

struct MissedReadingsViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return MissedReadingsViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct FastRiseDropViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return FastRiseDropViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct PersistentHighViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return PersistentHighViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct LowPredictionViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return LowPredictionViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct AlertVolumeViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return AlertVolumeViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

struct SnoozeActionsViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return SnoozeActionsViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    NavigationView {
        AlarmView()
    }
}
