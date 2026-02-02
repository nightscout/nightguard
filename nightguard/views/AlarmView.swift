//
//  AlarmView.swift
//  nightguard
//
//  SwiftUI version of AlarmViewController
//

import SwiftUI
import UniformTypeIdentifiers

struct AlarmView: View {
    @State private var disableAllAlerts = AlarmRule.areAlertsGenerallyDisabled.value
    @State private var highBGValue: Float = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfAboveValue.value))
    @State private var lowBGValue: Float = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfBelowValue.value))
    @State private var smartSnoozeEnabled = AlarmRule.isSmartSnoozeEnabled.value
    @ObservedObject private var alarmService = AlarmNotificationService.singleton
    @State private var showDisableAlertsConfirmation = false
    @State private var showInvalidChangeAlert = false
    @State private var invalidChangeMessage = ""

    // State variables for detail text updates
    @State private var missedReadingsDetail = ""
    @State private var fastRiseDropDetail = ""
    @State private var persistentHighDetail = ""
    @State private var lowPredictionDetail = ""
    @State private var ageAlertsDetail = ""

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
                                highBGValue = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfAboveValue.value))
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
                                lowBGValue = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfBelowValue.value))
                                return
                            }
                            UserDefaultsRepository.lowerBound.value = mgdlValue
                        }
                    }
                }

                // Other Alerts section
                Section(header: Text("Other Alerts")) {
                    if #available(iOS 14.0, *) {
                        NavigationLink(destination: AlarmSoundView()) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Alarm Sound")
                                Text("Define your own Alarm Sound by uploading an mp3 file from your iCloud account.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: MissedReadingsView()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Missed Readings")
                            Text(missedReadingsDetail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: FastRiseDropView()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fast Rise/Drop")
                            Text(fastRiseDropDetail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: PersistentHighView()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Persistent High")
                            Text(persistentHighDetail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: LowPredictionView()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Low Prediction")
                            Text(lowPredictionDetail)
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
                    Toggle("Alert Notifications", isOn: Binding(
                        get: { alarmService.publishedEnabled },
                        set: { alarmService.enabled = $0 }
                    ))
                }

                // Additional Settings section
                Section {
                    NavigationLink(destination: AlertVolumeView()) {
                        Text("Alert Volume")
                    }

                    NavigationLink(destination: SnoozeActionsView()) {
                        Text("Snoozing Actions")
                    }
                }

            }
        }
        .accentColor(Color.nightguardAccent)
        .navigationTitle("Alarms")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateDetailText()
        }
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

    private func updateDetailText() {
        missedReadingsDetail = getMissedReadingsDetail()
        fastRiseDropDetail = getFastRiseDropDetail()
        persistentHighDetail = getPersistentHighDetail()
        lowPredictionDetail = getLowPredictionDetail()
        ageAlertsDetail = getAgeAlertsDetail()
    }

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

    private func getAgeAlertsDetail() -> String {
        let sensorWarning = UserDefaultsRepository.sensorAgeHoursUntilWarning.value / 24
        let cannulaTotalHours = UserDefaultsRepository.cannulaAgeHoursUntilWarning.value
        let cannulaDays = cannulaTotalHours / 24
        let cannulaHours = cannulaTotalHours % 24
        let batteryWarning = UserDefaultsRepository.batteryAgeHoursUntilWarning.value / 24

        let cannulaText = cannulaDays > 0
            ? String(format: "%dd %dh", cannulaDays, cannulaHours)
            : String(format: "%dh", cannulaHours)

        return String(format: NSLocalizedString("Sensor: %dd, Cannula: %@, Battery: %dd", comment: ""),
                      sensorWarning, cannulaText, batteryWarning)
    }
}

// MARK: - SwiftUI Alarm Subviews

// MARK: - Missed Readings View
struct MissedReadingsView: View {
    @State private var missedReadingsEnabled = AlarmRule.noDataAlarmEnabled.value
    @State private var selectedMinutes = AlarmRule.minutesWithoutValues.value
    @State private var showDisableConfirmation = false

    private let alarmOptions = [15, 20, 25, 30, 35, 40, 45]

    var body: some View {
        Form {
            Section(
                footer: Text("Alerts when no data is received for a longer period. We suggest leaving this check ALWAYS ON.")
                    .font(.footnote)
            ) {
                Toggle("Missed Readings", isOn: $missedReadingsEnabled)
                    .onChange(of: missedReadingsEnabled) { newValue in
                        if newValue {
                            AlarmRule.noDataAlarmEnabled.value = newValue
                        } else {
                            showDisableConfirmation = true
                        }
                    }
            }

            if missedReadingsEnabled {
                Section(header: Text("Alert when no data for more than")) {
                    ForEach(alarmOptions, id: \.self) { option in
                        Button(action: {
                            selectedMinutes = option
                            AlarmRule.minutesWithoutValues.value = option
                        }) {
                            HStack {
                                Text("\(option) Minutes")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedMinutes == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
            }
        }
        .accentColor(Color.nightguardAccent)
        .navigationTitle("Missed Readings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            missedReadingsEnabled = AlarmRule.noDataAlarmEnabled.value
            selectedMinutes = AlarmRule.minutesWithoutValues.value
        }
        .alert("ARE YOU SURE?", isPresented: $showDisableConfirmation) {
            Button("No", role: .cancel) {
                missedReadingsEnabled = true
            }
            Button("Yes", role: .destructive) {
                AlarmRule.noDataAlarmEnabled.value = false
            }
        } message: {
            Text("For your safety, keep this switch ON for receiving alarms when no readings!")
        }
    }
}

// MARK: - Fast Rise/Drop View
struct FastRiseDropView: View {
    @State private var fastRiseDropEnabled = AlarmRule.isEdgeDetectionAlarmEnabled.value
    @State private var consecutiveReadings = AlarmRule.numberOfConsecutiveValues.value
    @State private var deltaValue = Float(UnitsConverter.mgdlToDisplayUnits("\(AlarmRule.deltaAmount.value)")) ?? 8.0

    var body: some View {
        Form {
            Section(
                footer: Text("Alerts when a fast BG rise or drop is detected in the last consecutive readings.")
                    .font(.footnote)
            ) {
                Toggle("Fast Rise/Drop", isOn: $fastRiseDropEnabled)
                    .onChange(of: fastRiseDropEnabled) { newValue in
                        AlarmRule.isEdgeDetectionAlarmEnabled.value = newValue
                    }
            }

            if fastRiseDropEnabled {
                Section(
                    header: Text("Consecutive Readings"),
                    footer: Text("How many consecutive readings to consider.")
                        .font(.footnote)
                ) {
                    Picker("Consecutive Readings", selection: $consecutiveReadings) {
                        ForEach([2, 3, 4, 5], id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: consecutiveReadings) { newValue in
                        AlarmRule.numberOfConsecutiveValues.value = newValue
                    }
                }

                Section(
                    header: Text("Delta"),
                    footer: Text("The difference (delta) between two individual readings.")
                        .font(.footnote)
                ) {
                    HStack {
                        Text("Delta")
                        Spacer()
                        Stepper(
                            "\(deltaValue.cleanValue) \(UserDefaultsRepository.units.value.description)",
                            value: $deltaValue,
                            in: (UserDefaultsRepository.units.value == .mmol ? 0.1 : 1)...(UserDefaultsRepository.units.value == .mmol ? 2.0 : 36),
                            step: UserDefaultsRepository.units.value == .mmol ? 0.1 : 1
                        )
                        .onChange(of: deltaValue) { newValue in
                            AlarmRule.deltaAmount.value = UnitsConverter.displayValueToMgdl(newValue)
                        }
                    }
                }
            }
        }
        .accentColor(Color.nightguardAccent)
        .navigationTitle("Fast Rise/Drop")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fastRiseDropEnabled = AlarmRule.isEdgeDetectionAlarmEnabled.value
            consecutiveReadings = AlarmRule.numberOfConsecutiveValues.value
            deltaValue = Float(UnitsConverter.mgdlToDisplayUnits("\(AlarmRule.deltaAmount.value)")) ?? 8.0
        }
    }
}

// MARK: - Persistent High View
struct PersistentHighView: View {
    @State private var persistentHighEnabled = AlarmRule.isPersistentHighEnabled.value
    @State private var selectedMinutes = AlarmRule.persistentHighMinutes.value
    @State private var urgentHighValue: Float = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.persistentHighUpperBound.value))

    private let alarmOptions = [15, 20, 30, 45, 60, 90, 120]

    var body: some View {
        Form {
            Section(
                footer: Text("Alerts when the BG remains high for a longer period. When on, this alert will delay the high BG alert until the period elapsed or until reaching a maximum BG level (urgent high).")
                    .font(.footnote)
            ) {
                Toggle("Persistent High", isOn: $persistentHighEnabled)
                    .onChange(of: persistentHighEnabled) { newValue in
                        AlarmRule.isPersistentHighEnabled.value = newValue
                    }
            }

            if persistentHighEnabled {
                Section(header: Text("Alert when high BG for more than")) {
                    ForEach(alarmOptions, id: \.self) { option in
                        Button(action: {
                            selectedMinutes = option
                            AlarmRule.persistentHighMinutes.value = option
                        }) {
                            HStack {
                                Text("\(option) Minutes")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedMinutes == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }

                Section(
                    header: Text("Urgent High"),
                    footer: Text("Alerts anytime when the blood glucose raises above this value.")
                        .font(.footnote)
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Urgent High")
                            Spacer()
                            Text("\(Int(urgentHighValue)) \(UserDefaultsRepository.units.value.description)")
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $urgentHighValue,
                            in: Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfAboveValue.value))...Float(UnitsConverter.mgdlToDisplayUnits(300)),
                            step: 1
                        )
                        .onChange(of: urgentHighValue) { newValue in
                            let mgdlValue = UnitsConverter.displayValueToMgdl(newValue)
                            AlarmRule.persistentHighUpperBound.value = mgdlValue
                        }
                    }
                }
            }
        }
        .accentColor(Color.nightguardAccent)
        .navigationTitle("Persistent High")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            persistentHighEnabled = AlarmRule.isPersistentHighEnabled.value
            selectedMinutes = AlarmRule.persistentHighMinutes.value
            urgentHighValue = Float(UnitsConverter.mgdlToDisplayUnits(AlarmRule.persistentHighUpperBound.value))
        }
    }
}

// MARK: - Low Prediction View
struct LowPredictionView: View {
    @State private var lowPredictionEnabled = AlarmRule.isLowPredictionEnabled.value
    @State private var selectedMinutes = AlarmRule.minutesToPredictLow.value

    private let alarmOptions = [5, 10, 15, 20, 25, 30]

    var body: some View {
        Form {
            Section(
                footer: Text("Alerts when a low BG value is predicted in the near future (if the current trend is continued).")
                    .font(.footnote)
            ) {
                Toggle("Low Prediction", isOn: $lowPredictionEnabled)
                    .onChange(of: lowPredictionEnabled) { newValue in
                        AlarmRule.isLowPredictionEnabled.value = newValue
                    }
            }

            if lowPredictionEnabled {
                Section(header: Text("Prediction interval")) {
                    ForEach(alarmOptions, id: \.self) { option in
                        Button(action: {
                            selectedMinutes = option
                            AlarmRule.minutesToPredictLow.value = option
                        }) {
                            HStack {
                                Text("\(option) Minutes")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedMinutes == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
            }
        }
        .accentColor(Color.nightguardAccent)
        .navigationTitle("Low Prediction")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            lowPredictionEnabled = AlarmRule.isLowPredictionEnabled.value
            selectedMinutes = AlarmRule.minutesToPredictLow.value
        }
    }
}

// MARK: - Alert Volume View
struct AlertVolumeView: View {
    @State private var overrideSystemVolume = AlarmSound.overrideSystemOutputVolume.value
    @State private var volume = AlarmSound.systemOutputVolume.value
    @State private var progressiveVolume = Int(AlarmSound.fadeInTimeInterval.value)
    @State private var vibrate = AlarmSound.vibrate.value
    @State private var isTestingAlarm = false

    private let progressiveVolumeOptions = [0, 30, 60, 120, 300, 600, 900, 1200]

    var body: some View {
        Form {
            Section(
                header: Text("Alert Volume"),
                footer: Text("If overriding the system output volume, your custom volume level will be used rather than phone's current volume level.")
                    .font(.footnote)
            ) {
                Toggle("Override System Volume", isOn: $overrideSystemVolume)
                    .onChange(of: overrideSystemVolume) { newValue in
                        AlarmSound.overrideSystemOutputVolume.value = newValue
                    }

                if overrideSystemVolume {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "speaker.wave.1.fill")
                                .foregroundColor(.gray)
                            Slider(value: $volume, in: 0...1)
                                .onChange(of: volume) { newValue in
                                    AlarmSound.systemOutputVolume.value = newValue
                                }
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

            Section(
                footer: Text("If selected, the alert will start quietly and increase the volume gradualy, reaching the maximum volume in selected time interval.")
                    .font(.footnote)
            ) {
                Picker("Progressive Volume", selection: $progressiveVolume) {
                    ForEach(progressiveVolumeOptions, id: \.self) { option in
                        Text(progressiveVolumeLabel(for: option)).tag(option)
                    }
                }
                .onChange(of: progressiveVolume) { newValue in
                    AlarmSound.fadeInTimeInterval.value = TimeInterval(newValue)
                }
            }

            Section {
                Toggle("Vibrate", isOn: $vibrate)
                    .onChange(of: vibrate) { newValue in
                        AlarmSound.vibrate.value = newValue
                    }
            }

            Section {
                Button(action: {
                    AlarmSound.isTesting = true
                    if AlarmSound.isPlaying {
                        AlarmSound.stop()
                        isTestingAlarm = false
                    } else {
                        AlarmSound.play()
                        isTestingAlarm = true
                    }
                }) {
                    Text(isTestingAlarm ? "Stop Alert" : "Test Alert")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(isTestingAlarm ? .red : Color.nightguardAccent)
                }
            }
        }
        .accentColor(Color.nightguardAccent)
        .navigationTitle("Alert Volume")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            overrideSystemVolume = AlarmSound.overrideSystemOutputVolume.value
            volume = AlarmSound.systemOutputVolume.value
            progressiveVolume = Int(AlarmSound.fadeInTimeInterval.value)
            vibrate = AlarmSound.vibrate.value
        }
        .onDisappear {
            if AlarmSound.isTesting {
                AlarmSound.isTesting = false
                AlarmSound.stop()
            }
        }
    }

    private func progressiveVolumeLabel(for seconds: Int) -> String {
        if seconds == 0 {
            return NSLocalizedString("Off", comment: "")
        } else if seconds < 60 {
            return "\(seconds) \(NSLocalizedString("seconds", comment: ""))"
        } else {
            return "\(seconds / 60) \(NSLocalizedString("minutes", comment: ""))"
        }
    }
}

// MARK: - Snooze Actions View
struct SnoozeActionsView: View {
    @State private var shakingAction = UserDefaultsRepository.shakingOnAlertSnoozeOption.value
    @State private var volumeKeysAction = UserDefaultsRepository.volumeKeysOnAlertSnoozeOption.value

    private let quickActionCodes: [QuickSnoozeOption] = [
        .doNothing,
        .showSnoozePopup,
        .snoozeOneMinute,
        .snoozeFiveMinutes,
        .snoozeTenMinutes
    ]

    var body: some View {
        Form {
            Section(
                footer: Text("After an alert started, sometimes it is important to have a shortcut, a quick way to stop it for the moment.")
                    .font(.footnote)
            ) {}

            Section(
                header: Text("Quick Snoozing"),
                footer: Text("NOTE: snoozing with volume buttons is enabled only if the \"Override System Volume\" option is ON (Alert Volume screen)")
                    .font(.footnote)
            ) {
                Picker("Shaking the phone", selection: $shakingAction) {
                    ForEach(quickActionCodes, id: \.self) { option in
                        Text(option.description).tag(option)
                    }
                }
                .onChange(of: shakingAction) { newValue in
                    UserDefaultsRepository.shakingOnAlertSnoozeOption.value = newValue
                }

                Picker("Volume Buttons", selection: $volumeKeysAction) {
                    ForEach(quickActionCodes, id: \.self) { option in
                        Text(option.description).tag(option)
                    }
                }
                .onChange(of: volumeKeysAction) { newValue in
                    UserDefaultsRepository.volumeKeysOnAlertSnoozeOption.value = newValue
                }
            }
        }
        .accentColor(Color.nightguardAccent)
        .navigationTitle("Snoozing Actions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            shakingAction = UserDefaultsRepository.shakingOnAlertSnoozeOption.value
            volumeKeysAction = UserDefaultsRepository.volumeKeysOnAlertSnoozeOption.value
        }
    }
}

// MARK: - Alarm Sound View
struct AlarmSoundView: View {
    @State private var customAlarmSoundEnabled = AlarmSound.playCustomAlarmSound.value
    @State private var alarmName = AlarmSound.customName.value
    @State private var isTestingAlarm = false
    @State private var showDocumentPicker = false

    var body: some View {
        Form {
            Section(
                footer: Text("If activated, a user defined alarm sound will be used.")
                    .font(.footnote)
            ) {
                Toggle("Custom Alarm Sound", isOn: $customAlarmSoundEnabled)
                    .onChange(of: customAlarmSoundEnabled) { newValue in
                        AlarmSound.playCustomAlarmSound.value = newValue
                    }
            }

            if customAlarmSoundEnabled {
                Section {
                    HStack {
                        Text("Alarm Name")
                        Spacer()
                        Text(alarmName.isEmpty ? "None" : alarmName)
                            .foregroundColor(.secondary)
                    }

                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        Text("Pick Custom Alarm Sound")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        AlarmSound.isTesting = true
                        if AlarmSound.isPlaying {
                            AlarmSound.stop()
                            isTestingAlarm = false
                        } else {
                            AlarmSound.play()
                            isTestingAlarm = true
                        }
                    }) {
                        Text(isTestingAlarm ? "Stop Alert" : "Test Alert")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(isTestingAlarm ? .red : Color.nightguardAccent)
                    }
                }
            }
        }
        .accentColor(Color.nightguardAccent)
        .navigationTitle("Alarm Sound")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            customAlarmSoundEnabled = AlarmSound.playCustomAlarmSound.value
            alarmName = AlarmSound.customName.value
        }
        .sheet(isPresented: $showDocumentPicker) {
            if #available(iOS 14.0, *) {
                DocumentPicker(alarmName: $alarmName)
            }
        }
        .onDisappear {
            if AlarmSound.isTesting {
                AlarmSound.isTesting = false
                AlarmSound.stop()
            }
        }
    }
}

// MARK: - Document Picker for Alarm Sound
@available(iOS 14.0, *)
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var alarmName: String
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.mp3, .wav])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let customSoundUrl = urls.first else { return }

            // create a local copy
            guard let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }

            // lets create your destination file url
            guard let localUrl = URL(string: "customAlarmSound.mp3", relativeTo: documentsDirectoryURL) else {
                print("Can't read customAlarmSound.mp3")
                return
            }

            do {
                try? FileManager.default.removeItem(at: localUrl)
                // Call this to get access to the icloud files:
                if customSoundUrl.startAccessingSecurityScopedResource() {
                    try FileManager.default.copyItem(at: customSoundUrl, to: localUrl)

                    AlarmSound.alarmSoundUri.value = localUrl.relativeString
                    if let filename = customSoundUrl.pathComponents.last {
                        AlarmSound.customName.value = filename
                        parent.alarmName = filename
                    }
                }
            } catch (let writeError) {
                print("error writing file \(localUrl) : \(writeError)")
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}


#Preview {
    NavigationView {
        AlarmView()
    }
    .navigationViewStyle(StackNavigationViewStyle())
}
