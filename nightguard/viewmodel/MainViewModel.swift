//
//  MainViewModel.swift
//  nightguard
//
//  Unified MainViewModel for iOS and watchOS
//  Based on the better-crafted watch version with iOS enhancements
//

import Foundation
import SwiftUI
import SpriteKit
#if os(watchOS)
import WatchConnectivity
import WidgetKit
#endif
#if os(iOS)
import Combine
#endif

class MainViewModel: ObservableObject, Identifiable {

    // MARK: - Published Properties - Current Nightscout Data
    @Published var nightscoutData: NightscoutData?

    // MARK: - Published Properties - Colors
    @Published var sgvColor = Color.white
    @Published var sgvDeltaColor = Color.white
    @Published var arrowColor = Color.white
    @Published var timeColor = Color.white
    @Published var uploaderBatteryColor: Color = Color.white

    // MARK: - Published Properties - Care Data with Colors
    @Published var cannulaAgeString: String?
    @Published var cannulaAgeColor: Color = Color.white
    @Published var sensorAgeString: String?
    @Published var sensorAgeColor: Color = Color.white
    @Published var batteryAgeString: String?
    @Published var batteryAgeColor: Color = Color.white

    // MARK: - Published Properties - Device Status
    @Published var reservoir: String = "?U"
    @Published var reservoirColor: Color = Color.white
    @Published var activeProfile: String = "---"
    @Published var temporaryBasal: String = "---"
    @Published var temporaryTarget: String = "---"

    // MARK: - Published Properties - IOB/COB (iOS specific but harmless on watch)
    @Published var cobValue: String = "0g"
    @Published var iobValue: String = "0.0U"

    // MARK: - Published Properties - UI State
    @Published var error: Error?
    @Published var active: Bool = false
    @Published var alarmRuleMessage: String = ""
    @Published var showCareAndLoopData: Bool = true

    // MARK: - Published Properties - Chart
    @Published var skScene: ChartScene
    @Published var cachedTodaysBgValues: [BloodSugar] = []
    @Published var cachedYesterdaysBgValues: [BloodSugar] = []

    #if os(watchOS)
    // MARK: - Watch-Specific Properties
    @Published var crownScrolls: Bool = true
    #endif

    #if os(iOS)
    // MARK: - iOS-Specific Properties
    @Published var bgValue: String = "---"
    @Published var bgColor: Color = .white
    @Published var deltaValue: String = "---"
    @Published var deltaArrows: String = "-"
    @Published var deltaColor: Color = .white
    @Published var timeValue: String = "--:--"
    @Published var lastUpdateValue: String = "0min"
    @Published var lastUpdateColor: Color = .white
    @Published var batteryValue: String = "100%"
    @Published var batteryColor: Color = .white
    @Published var reservoirValue: String = "---"
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var showStatsPanelView: Bool = true
    @Published var showActionsMenu: Bool = true
    @Published var slideToSnoozeHeight: CGFloat = 80
    @Published var snoozeButtonText: String = "snooze"
    @Published var lowPredictionText: String = ""

    // Track if view is currently visible
    var isVisible: Bool = false

    // Timer for periodic updates
    private var timer: Timer?
    private let timeInterval: TimeInterval = 30.0

    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    private var observationTokens = [ObservationToken]()
    #endif

    // MARK: - Initialization
    init() {
        showCareAndLoopData = UserDefaultsRepository.showCareAndLoopData.value

        #if os(watchOS)
        let bounds = WKInterfaceDevice.current().screenBounds
        let chartSceneHeight = MainViewModel.determineSceneHeightFromCurrentWatchType(interfaceBounds: bounds)
        skScene = ChartScene(size: CGSize(width: bounds.width, height: chartSceneHeight), newCanvasWidth: bounds.width * 4, useContrastfulColors: false, showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value)
        #else
        // iOS initialization - scene will be set up later by the view
        let defaultSize = CGSize(width: 400, height: 400)
        skScene = ChartScene(size: defaultSize, newCanvasWidth: 2048, useContrastfulColors: false, showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value)
        setupiOSObservers()
        loadiOSInitialData()
        #endif

        // Read stored historical data
        TreatmentsStream.singleton.treatments = UserDefaultsRepository.treatments.value

        refreshData(forceRefresh: true, moveToLatestValue: true)

        alarmRuleMessage = determineInfoLabel()

        #if os(iOS)
        // Listen to alarm snoozing & play/stop alarm accordingly
        AlarmRule.onSnoozeTimestampChanged = { [weak self] in
            self?.evaluateAlarmActivationState()
        }
        #endif
    }

    #if os(iOS)
    // MARK: - iOS Setup
    private func setupiOSObservers() {
        UserDefaultsRepository.showStats.observeChanges { [weak self] value in
            self?.showStatsPanelView = value
        }

        UserDefaultsRepository.showCareAndLoopData.observeChanges { [weak self] value in
            self?.showCareAndLoopData = value
        }

        observationTokens.append(AlarmRule.areAlertsGenerallyDisabled.observeChanges { [weak self] value in
            self?.showActionsMenu = !value
            self?.slideToSnoozeHeight = value ? 0 : 80
        })

        observationTokens.append(UserDefaultsRepository.upperBound.observeChanges { [weak self] _ in
            self?.repaintChartWithCurrentData()
        })

        observationTokens.append(UserDefaultsRepository.lowerBound.observeChanges { [weak self] _ in
            self?.repaintChartWithCurrentData()
        })
    }

    private func loadiOSInitialData() {
        showStatsPanelView = UserDefaultsRepository.showStats.value
        showCareAndLoopData = UserDefaultsRepository.showCareAndLoopData.value
        showActionsMenu = !AlarmRule.areAlertsGenerallyDisabled.value
        slideToSnoozeHeight = AlarmRule.areAlertsGenerallyDisabled.value ? 0 : 80
        updateSnoozeButtonText()
    }

    // MARK: - iOS Timer Management
    func startTimer(forceRepaint: Bool = false) {
        doPeriodicUpdate(forceRepaint: forceRepaint)

        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
            self?.doPeriodicUpdate(forceRepaint: false)
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func doPeriodicUpdate(forceRepaint: Bool) {
        paintCurrentTime()
        refreshData(forceRefresh: false, moveToLatestValue: forceRepaint)
        AppleHealthService.singleton.sync()
        updateSnoozeButtonText()
    }

    func handleVisibilityChange(isVisible: Bool) {
        let wasInvisible = !self.isVisible
        self.isVisible = isVisible

        if isVisible && wasInvisible {
            startTimer(forceRepaint: true)
        } else if !isVisible {
            stopTimer()
        }
    }

    private func paintCurrentTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        timeValue = formatter.string(from: Date())
    }

    func updateSnoozeButtonText() {
        if AlarmRule.isSnoozed() {
            let remainingMinutes = AlarmRule.getRemainingSnoozeMinutes()
            snoozeButtonText = String(format: NSLocalizedString("Snoozed for %dmin", comment: ""), remainingMinutes)
        } else {
            snoozeButtonText = NSLocalizedString("snooze", comment: "")
        }
        
        // Use AlarmRule.getAlarmActivationReason to get the text to show on the snooze button
        lowPredictionText = AlarmRule.getAlarmActivationReason(ignoreSnooze: true) ?? ""
    }

    func evaluateAlarmActivationState() {
        if AlarmRule.isAlarmActivated() {
            AlarmSound.play()
        } else {
            if !AlarmSound.isTesting {
                AlarmSound.stop()
            }
        }
        updateSnoozeButtonText()
    }
    #endif

    #if os(watchOS)
    // MARK: - Watch-Specific Methods

    // Retrieve data that has been obtained from a background task.
    // Update the UI, Complication and send Notifications
    func pushBackgroundData(newNightscoutData: NightscoutData) {
        calculateColors(nightscoutData: newNightscoutData)
        self.nightscoutData = newNightscoutData
        self.active = false
        updateComplication()
    }

    fileprivate func updateComplication() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    fileprivate static func determineSceneHeightFromCurrentWatchType(interfaceBounds: CGRect) -> CGFloat {
        if (interfaceBounds.height >= 224.0) {
            // Apple Watch 44mm
            return 130.0
        }
        if (interfaceBounds.height >= 195.0) {
            // Apple Watch 42mm
            return 115.0
        }

        // interfaceBounds.height == 170.0
        // Apple Watch 40mm/38mm
        return 115.0
    }

    func toggleCrownScrolls() {
        crownScrolls = !crownScrolls
    }

    func eventuallyNotify() {
        if !AlarmRule.isAlarmActivated() {
            return
        }

        RequestAlarmNotificationMessage().send()
    }

    func eventuallyPlayAlarmSound() {
        if !AlarmRule.isAlarmActivated() {
            return
        }

        if !AppState.isUIActive {
            // We don't like to have alarms e.g. if the watch is on the charger and in background
            // State. So don't play sounds in that case
            return
        }

        // Play an alarm if the app user interface is active on the watch
        WKInterfaceDevice.current().play(.notification)
    }
    #endif

    // MARK: - Shared Methods

    func refreshData(forceRefresh: Bool, moveToLatestValue: Bool) {
        showCareAndLoopData = UserDefaultsRepository.showCareAndLoopData.value

        loadCurrentBgData(forceRefresh: forceRefresh)
        loadCareData()
        loadDeviceStatusData()
        loadChartData(forceRepaint: forceRefresh, moveToLatestValue: moveToLatestValue)
        loadTreatments()

        alarmRuleMessage = determineInfoLabel()

        #if os(watchOS)
        eventuallyPlayAlarmSound()
        #else
        evaluateAlarmActivationState()
        #endif
    }

    fileprivate func loadTreatments() {
        NightscoutService.singleton.readLatestTreatements { treatments in
            TreatmentsStream.singleton.addNewJsonTreatments(jsonTreatments: treatments)
        }
    }

    func determineInfoLabel() -> String {
        if !AlarmRule.isSnoozed() {
            if let alarmReason = AlarmRule.getAlarmActivationReason() {
                return alarmReason
            } else {
                return ""
            }
        }

        return String(format: NSLocalizedString("Snoozed %dmin", comment: "Snoozed duration on watch"), AlarmRule.getRemainingSnoozeMinutes())
    }

    func loadCurrentBgData(forceRefresh: Bool) {
        // do not call refresh again if not needed
        guard forceRefresh || !NightscoutCacheService.singleton.hasCurrentNightscoutDataPendingRequests else {
            return
        }

        self.nightscoutData = NightscoutCacheService.singleton.loadCurrentNightscoutData(forceRefresh: forceRefresh) { [unowned self] result in

            guard let result = result else { return }

            dispatchOnMain { [unowned self] in

                guard self.active else { return }

                switch result {
                case .data(let newNightscoutData):
                    calculateColors(nightscoutData: newNightscoutData)

                    self.nightscoutData = newNightscoutData
                    self.active = false
                    alarmRuleMessage = determineInfoLabel()

                    #if os(watchOS)
                    eventuallyNotify()
                    #else
                    paintCurrentBgDataiOS(currentNightscoutData: newNightscoutData)

                    if SharedUserDefaultsRepository.showBGOnAppBadge.value {
                        UIApplication.shared.setCurrentBGValueOnAppBadge()
                    }
                    WatchService.singleton.sendToWatchCurrentNightwatchData()
                    #endif

                case .error(let error):
                    self.error = error
                    self.active = false

                    #if os(iOS)
                    self.errorMessage = "❌ \(error.localizedDescription)"
                    self.showError = true
                    #endif
                }
            }
        }

        if let nsData = self.nightscoutData {
            calculateColors(nightscoutData: nsData)

            #if os(iOS)
            paintCurrentBgDataiOS(currentNightscoutData: nsData)
            #endif
        }

        self.active = NightscoutCacheService.singleton.hasCurrentNightscoutDataPendingRequests
    }

    #if os(iOS)
    private func paintCurrentBgDataiOS(currentNightscoutData: NightscoutData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if currentNightscoutData.sgv == "---" {
                self.bgValue = "---"
            } else {
                self.bgValue = UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv)
            }

            self.bgColor = self.sgvColor
            self.deltaColor = self.sgvDeltaColor
            self.lastUpdateColor = self.timeColor

            self.deltaValue = UnitsConverter.mgdlToDisplayUnitsWithSign("\(currentNightscoutData.bgdelta)")
            self.deltaArrows = currentNightscoutData.bgdeltaArrow

            self.lastUpdateValue = currentNightscoutData.timeString

            self.batteryValue = currentNightscoutData.battery
            self.batteryColor = self.uploaderBatteryColor

            if !currentNightscoutData.iob.isEmpty {
                self.iobValue = currentNightscoutData.iob
            }
            if !currentNightscoutData.cob.isEmpty {
                self.cobValue = currentNightscoutData.cob
            }
            
            // Update Live Activity
            if #available(iOS 16.1, *) {
                 LiveActivityManager.shared.update(with: currentNightscoutData)
            }

            // Notify that data has been updated
            NotificationCenter.default.post(name: NSNotification.Name("NightscoutDataUpdated"), object: nil)
        }
    }
    #endif

    fileprivate func calculateColors(nightscoutData: NightscoutData) {
        self.sgvColor = Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)))
        self.sgvDeltaColor = Color(UIColorChanger.getDeltaLabelColor(
            UnitsConverter.mgdlToDisplayUnits(nightscoutData.bgdelta)))
        self.arrowColor = Color(
            UIColorChanger.getDeltaLabelColor(
                UnitsConverter.mgdlToDisplayUnits(nightscoutData.bgdelta)))
        self.timeColor = Color(UIColorChanger.getTimeLabelColor(nightscoutData.time))
        self.uploaderBatteryColor = Color(UIColorChanger.getBatteryLabelColor(nightscoutData.battery))
    }

    fileprivate func loadCareData() {
        let sensorAge: Date = NightscoutCacheService.singleton.getSensorChangeTime()
        self.sensorAgeColor = sensorAge.determineColorDependingOn(
            hoursUntilWarning: UserDefaultsRepository.sensorAgeHoursUntilWarning.value,
            hoursUntilCritical: UserDefaultsRepository.sensorAgeHoursUntilCritical.value)
        self.sensorAgeString = sensorAge.convertToAge(prefix: "S ")

        let cannulaAge: Date = NightscoutCacheService.singleton.getCannulaChangeTime()
        self.cannulaAgeColor = cannulaAge.determineColorDependingOn(
            hoursUntilWarning: UserDefaultsRepository.cannulaAgeHoursUntilWarning.value,
            hoursUntilCritical: UserDefaultsRepository.cannulaAgeHoursUntilCritical.value)
        self.cannulaAgeString = cannulaAge.convertToAge(prefix: "C ")

        let batteryAge: Date = NightscoutCacheService.singleton.getPumpBatteryChangeTime()
        self.batteryAgeColor = batteryAge.determineColorDependingOn(
            hoursUntilWarning: UserDefaultsRepository.batteryAgeHoursUntilWarning.value,
            hoursUntilCritical: UserDefaultsRepository.batteryAgeHoursUntilCritical.value)
        self.batteryAgeString = batteryAge.convertToAge(prefix: "B ")
    }

    fileprivate func loadDeviceStatusData() {
        let deviceStatusData = NightscoutCacheService.singleton.getDeviceStatusData({ [unowned self] result in
            self.extractDeviceStatusData(deviceStatusData: result)
        })

        self.extractDeviceStatusData(deviceStatusData: deviceStatusData)
    }

    fileprivate func extractDeviceStatusData(deviceStatusData: DeviceStatusData) {
        #if os(watchOS)
        self.reservoir = "R \(String(describing: deviceStatusData.reservoirUnits))"
        let profilePrefixCount = 4
        let profilePostfixCount = 6
        #else
        self.reservoir = "R \(String(describing: deviceStatusData.reservoirUnits))"
        self.reservoirValue = "R \(deviceStatusData.reservoirUnits)U"
        let profilePrefixCount = 7
        let profilePostfixCount = 7
        #endif

        self.reservoirColor = UIColorChanger.getReservoirColor(deviceStatusData.reservoirUnits)
        self.activeProfile = deviceStatusData.activePumpProfile.trimInfix(keepPrefixCharacterCount: profilePrefixCount, keepPostfixCharacterCount: profilePostfixCount)

        if deviceStatusData.temporaryBasalRate != "" &&
            deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes() > 0 {

            self.temporaryBasal = "TB \(deviceStatusData.temporaryBasalRate)% \(deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes())m"
        } else {
            self.temporaryBasal = "TB --"
        }

        NightscoutCacheService.singleton.getTemporaryTargetData() { temporaryTargetData in
            if temporaryTargetData.activeUntilDate.remainingMinutes() > 0 {
                #if os(watchOS)
                self.temporaryTarget = "TT \(UnitsConverter.mgdlToDisplayUnits(String(describing: temporaryTargetData.targetTop))) \(temporaryTargetData.activeUntilDate.remainingMinutes())m"
                #else
                self.temporaryTarget = "TT \(UnitsConverter.mgdlToDisplayUnits("\(temporaryTargetData.targetTop)")) \(temporaryTargetData.activeUntilDate.remainingMinutes())m"
                #endif
            } else {
                self.temporaryTarget = "TT --"
            }
        }
    }



    func loadChartData(forceRepaint: Bool, moveToLatestValue: Bool) {
        // show a message if the today & yesterday data is missing, we're gonna load them now (will show on first install and when URI changes)
        if UserDefaultsRepository.baseUri.exists && NightscoutCacheService.singleton.isEmpty && NightscoutDataRepository.singleton.isEmpty {
            // TODO: Show loading message
        }

        let newCachedTodaysBgValues: [BloodSugar]
        if NightscoutCacheService.singleton.hasTodaysBgDataPendingRequests {
            newCachedTodaysBgValues = NightscoutDataRepository.singleton.loadTodaysBgData()
        } else {
            newCachedTodaysBgValues = NightscoutCacheService.singleton.loadTodaysData { [unowned self] result in
                guard let result = result else { return }

                dispatchOnMain { [unowned self] in
                    if case .data(let newTodaysData) = result {
                        self.cachedTodaysBgValues = newTodaysData
                        paintChartData(todaysData: cachedTodaysBgValues, yesterdaysData: cachedYesterdaysBgValues, moveToLatestValue: true)
                    }
                }
            }
        }
        cachedTodaysBgValues = newCachedTodaysBgValues

        let newCachedYesterdaysBgValues: [BloodSugar]
        if NightscoutCacheService.singleton.hasYesterdaysBgDataPendingRequests {
            newCachedYesterdaysBgValues = NightscoutDataRepository.singleton.loadYesterdaysBgData()
        } else {
            newCachedYesterdaysBgValues = NightscoutCacheService.singleton.loadYesterdaysData { [unowned self] result in
                guard let result = result else { return }

                dispatchOnMain { [unowned self] in
                    if case .data(let newYesterdaysData) = result {
                        self.cachedYesterdaysBgValues = newYesterdaysData
                        paintChartData(todaysData: cachedTodaysBgValues, yesterdaysData: cachedYesterdaysBgValues, moveToLatestValue: true)
                    }
                }
            }
        }

        cachedYesterdaysBgValues = newCachedYesterdaysBgValues
        if forceRepaint {
            paintChartData(todaysData: cachedTodaysBgValues, yesterdaysData: cachedYesterdaysBgValues, moveToLatestValue: moveToLatestValue)
        }
    }

    fileprivate func paintChartData(todaysData: [BloodSugar], yesterdaysData: [BloodSugar], moveToLatestValue: Bool) {
        let todaysDataWithPrediction = todaysData + PredictionService.singleton.nextHourGapped

        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        let bounds = device.screenBounds
        let canvasWidth = bounds.width * 6

        skScene.paintChart(
            [todaysDataWithPrediction, yesterdaysData],
            newCanvasWidth: canvasWidth,
            maxYDisplayValue: CGFloat(UserDefaultsRepository.maximumBloodGlucoseDisplayed.value),
            moveToLatestValue: moveToLatestValue,
            displayDaysLegend: false,
            useConstrastfulColors: false,
            showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value)
        #else
        skScene.paintChart(
            [todaysDataWithPrediction, yesterdaysData],
            newCanvasWidth: CGFloat(2048),
            maxYDisplayValue: CGFloat(UserDefaultsRepository.maximumBloodGlucoseDisplayed.value),
            moveToLatestValue: moveToLatestValue,
            useContrastfulColors: false,
            showYesterdaysBgs: UserDefaultsRepository.showYesterdaysBgs.value)
        #endif
    }

    func repaintChartWithCurrentData() {
        paintChartData(todaysData: cachedTodaysBgValues, yesterdaysData: cachedYesterdaysBgValues, moveToLatestValue: true)
    }
}
