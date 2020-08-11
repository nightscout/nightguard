//
//  InterfaceController.swift
//  scoutwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity
import SpriteKit

@available(watchOSApplicationExtension 3.0, *)
class InterfaceController: WKInterfaceController, WKCrownDelegate {

    @IBOutlet var bgLabel: WKInterfaceLabel!
    @IBOutlet var deltaLabel: WKInterfaceLabel!
    @IBOutlet var deltaArrowLabel: WKInterfaceLabel!
    @IBOutlet var timeLabel: WKInterfaceLabel!
    @IBOutlet var batteryLabel: WKInterfaceLabel!
    @IBOutlet var spriteKitView: WKInterfaceSKScene!
    @IBOutlet var cobLabel: WKInterfaceLabel!
    @IBOutlet var iobLabel: WKInterfaceLabel!
    @IBOutlet var errorLabel: WKInterfaceLabel!
    @IBOutlet var errorGroup: WKInterfaceGroup!
    @IBOutlet var activityIndicatorImage: WKInterfaceImage!
    
    @IBOutlet var rawbgLabel: WKInterfaceLabel!
    @IBOutlet var noiseLabel: WKInterfaceLabel!
    @IBOutlet var rawValuesGroup: WKInterfaceGroup!
    
    @IBOutlet var nightSafeIndicator: WKInterfaceGroup!
    
    @IBOutlet var cannulaAgeLabel: WKInterfaceLabel!
    @IBOutlet var sensorAgeLabel: WKInterfaceLabel!
    @IBOutlet var batteryAgeLabel: WKInterfaceLabel!
    
    @IBOutlet var activeProfileLabel: WKInterfaceLabel!
    @IBOutlet var temporaryBasalLabel: WKInterfaceLabel!
    @IBOutlet var temporaryTargetLabel: WKInterfaceLabel!
    
    // set by AppMessageService when receiving messages/data from phone app and current bg data or charts should be repainted
    var shouldRepaintCurrentBgDataOnActivation = false
    var shouldRepaintChartsOnActivation = false
    
    fileprivate var chartScene : ChartScene = ChartScene(size: CGSize(width: 320, height: 280), newCanvasWidth: 1024)
    
    // timer to check continuously for new bgValues
    fileprivate var timer = Timer()
    // check every 30 Seconds whether new bgvalues should be retrieved
    fileprivate let timeInterval : TimeInterval = 30.0
    
    fileprivate var zoomingIsActive : Bool = false
    fileprivate var nrOfCrownRotations : Int = 0
    
    // Old values that have been read before
    fileprivate var cachedTodaysBgValues : [BloodSugar] = []
    fileprivate var cachedYesterdaysBgValues : [BloodSugar] = []
    
    fileprivate var isActive: Bool = false
    fileprivate var isFirstActivation: Bool = true
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Initialize the ChartScene
        let bounds = WKInterfaceDevice.current().screenBounds
        let chartSceneHeight = determineSceneHeightFromCurrentWatchType(interfaceBounds: bounds)
        chartScene = ChartScene(size: CGSize(width: bounds.width, height: chartSceneHeight), newCanvasWidth: bounds.width * 6)
        spriteKitView.presentScene(chartScene)
        
        activityIndicatorImage.setImageNamed("Activity")
        errorGroup.setHidden(true)
        nightSafeIndicator.setHidden(true)
        
        createMenuItems()
        
        BackgroundRefreshLogger.info("InterfaceController is awake!")
    }
    
    fileprivate func determineSceneHeightFromCurrentWatchType(interfaceBounds : CGRect) -> CGFloat {
        
        if (interfaceBounds.height >= 224.0) {
            // Apple Watch 44mm
            return 165.0
        }
        if (interfaceBounds.height >= 195.0) {
            // Apple Watch 42mm
            return 145.0
        }
        
        // interfaceBounds.height == 170.0
        // Apple Watch 38mm
        return 125.0
    }
    
    override func willActivate() {
        super.willActivate()
        
//        guard WKExtension.shared().applicationState != .background else {
//            return
//        }
        
        isActive = true
        nightSafeIndicator.setHidden(true)
        
        let currentNightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        updateInterface(withNightscoutData: currentNightscoutData, error: nil)
        
        // HACK: after updating to watchOS 5, the interface was not updated sometimes on watch activation, but it seems that if called after a little while, it works almost everytime (still not perfect, but... hey Apple, we want a fix here, on watchOS 4 there were no problems!)
        delay(0.4) { [unowned self] in
            self.delayedWillActivate()
        }
        
        // send watch sync request message to phone app; if phone app has different user default or snooze timestamp values, it will send back the right messages for keeping the devices in sync
        delay(1.0) { [weak self] in
            guard WKExtension.shared().applicationState == .active else {
                return
            }
            
            if !UserDefaultsRepository.baseUri.exists {
                self?.showMessage("Requesting data from phone...")
            }
            WatchSyncRequestMessage().send()
        }
    }
    
    private func delayedWillActivate() {
        guard isActive else { return }
        
        print("delayedWillActivate")
        
        sendNightSafeRequest()
        
        spriteKitView.isPaused = false
        
        // Start the timer to retrieve new bgValues and update the ui periodically
        // if the user keeps the display active for a longer time
        createNewTimerSingleton()
        
        // manually refresh the gui by fireing the timer
        updateNightscoutData(forceRefresh: isFirstActivation || shouldRepaintCurrentBgDataOnActivation, forceRepaintCharts: shouldRepaintChartsOnActivation)
                
        // Ask to get 8 minutes of cpu runtime to get the next values if
        // the app stays in frontmost state
        if #available(watchOSApplicationExtension 4.0, *) {
            WKExtension.shared().isFrontmostTimeoutExtended = true
        }
        
        crownSequencer.focus()
        crownSequencer.delegate = self
        
        paintChartData(todaysData: cachedTodaysBgValues, yesterdaysData: cachedYesterdaysBgValues, moveToLatestValue: false)
        loadAndPaintCareData()
        
        // reset the first activation flag!
        isFirstActivation = false
        // ... and the "should repaint charts" flag
        shouldRepaintCurrentBgDataOnActivation = false
        shouldRepaintChartsOnActivation = false
    }
    
    override func didAppear() {
        super.didAppear()
        
        spriteKitView.isPaused = false
        
        crownSequencer.focus()
        crownSequencer.delegate = self
    }
    
    override func willDisappear() {
        super.willDisappear()
        
        spriteKitView.isPaused = true
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        
        isActive = false
        timer.invalidate()
        spriteKitView.isPaused = true
    }
    
    // called when the crown rotates, rotationalDelta is the change since the last call (sign indicates direction).
    func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        
        if zoomingIsActive {
            nrOfCrownRotations += 1
            // only recognize every third rotation => Otherwise the watch will crash
            // because of too many calls a second
            if nrOfCrownRotations % 5 == 0 && abs(rotationalDelta) > 0.01 {
                chartScene.scale(1 + CGFloat(rotationalDelta), keepScale: true, infoLabelText: determineInfoLabel())
            }
        } else {
            chartScene.moveChart(rotationalDelta * 200)
        }
    }
    
    @objc func doInfoMenuAction() {
        self.presentController(withName: "InfoInterfaceController", context: nil)
    }
    
    @objc func doSnoozeMenuAction() {
        self.presentController(withName: "SnoozeInterfaceController", context: nil)
        loadAndPaintChartData(forceRepaint : true)
    }
    
    @objc func doRefreshMenuAction() {
        NightscoutCacheService.singleton.resetCache()
        
        loadAndPaintCurrentBgData(forceRefresh: true)
        loadAndPaintChartData(forceRepaint: true)
        loadAndPaintCareData()
    }
    
    @objc func doToogleZoomScrollAction() {
        zoomingIsActive = !zoomingIsActive
        createMenuItems()
    }
    
    @objc func doCloseMenuAction() {
        // nothing to do - closes automatically
    }
    
    fileprivate func createNewTimerSingleton() {
        if !timer.isValid {
            timer = Timer.scheduledTimer(timeInterval: timeInterval,
                                         target: self,
                                         selector: #selector(InterfaceController.timerDidEnd(_:)),
                                         userInfo: nil,
                                         repeats: true)
            // allow WatchOs to call this timer 30 seconds later as requested
            timer.tolerance = timeInterval
        }
    }
    
    fileprivate func updateNightscoutData(forceRefresh: Bool, forceRepaintCharts: Bool) {
        loadAndPaintCurrentBgData(forceRefresh: forceRefresh)
        loadAndPaintChartData(forceRepaint: forceRepaintCharts)
    }
        
    // check whether new Values should be retrieved
    @objc func timerDidEnd(_ timer:Timer){
        updateNightscoutData(forceRefresh: false, forceRepaintCharts: false)
    }
    
    @IBAction func onLabelsGroupDoubleTapped(_ sender: Any) {
        updateNightscoutData(forceRefresh: true, forceRepaintCharts: false)
    }
    
    @IBAction func onSpriteKitViewDoubleTapped(_ sender: Any) {
        updateNightscoutData(forceRefresh: true, forceRepaintCharts: false)
    }
    
    // this has to be created programmatically, since only this way
    // the item Zoom/Scroll can be toggled
    fileprivate func createMenuItems() {
        
        self.clearAllMenuItems()
        self.addMenuItem(with: WKMenuItemIcon.info, title:
            NSLocalizedString("Info", comment: "Watch Popup Info Label"), action: #selector(InterfaceController.doInfoMenuAction))
        self.addMenuItem(with: WKMenuItemIcon.resume, title:
            NSLocalizedString("Refresh", comment: "Watch Popup Refresh Label"), action: #selector(InterfaceController.doRefreshMenuAction))
        self.addMenuItem(with: WKMenuItemIcon.block, title:
            NSLocalizedString("Snooze", comment: "Watch Popup Snooze Label"), action: #selector(InterfaceController.doSnoozeMenuAction))
        self.addMenuItem(with: WKMenuItemIcon.more, title: zoomingIsActive
            ? NSLocalizedString("Scroll", comment:  "Watch Popup Scroll Label")
            : NSLocalizedString("Zoom", comment: "Watch Popup Zoom Label"), action: #selector(InterfaceController.doToogleZoomScrollAction))
    }
    
    // Returns true, if the size of one array changed
    fileprivate func valuesChanged(newCachedTodaysBgValues : [BloodSugar], newCachedYesterdaysBgValues : [BloodSugar]) -> Bool {
        
        return newCachedTodaysBgValues.count != cachedTodaysBgValues.count ||
                newCachedYesterdaysBgValues.count != cachedYesterdaysBgValues.count
    }
    
    func showMessage(_ message: String?, isError: Bool = false) {
        errorLabel.setText(message)
        errorLabel.setTextColor(isError ? .red : .black)
        errorGroup.setHidden(message == nil ? true : false)
    }
    
    func updateInterface(withNightscoutData nightscoutData: NightscoutData?, error: Error?) {
        
        // stop & hide the activity indicator
        self.activityIndicatorImage.stopAnimating()
        self.activityIndicatorImage.setHidden(true)
        
        if let error = error {
            
            // show errors ONLY when the interface is active (connection errors can be received while it is inactive... don't know for the moment why)
            // NOTE: actually, the whole UI should be updated only when the interface is active...
            if self.isActive {
                self.showMessage("❌ \(error.localizedDescription)", isError: true)
            } else {
                self.showMessage(nil)
            }
        } else if let nightscoutData = nightscoutData {
            self.showMessage(nil)
            self.paintCurrentBgData(currentNightscoutData: nightscoutData)
        }
    }
    
    func loadAndPaintCurrentBgData(forceRefresh: Bool) {

        // do not call refresh again if not needed
        guard forceRefresh || !NightscoutCacheService.singleton.hasCurrentNightscoutDataPendingRequests else {
            return
        }

        let currentNightscoutData = NightscoutCacheService.singleton.loadCurrentNightscoutData(forceRefresh: forceRefresh) { [unowned self] result in
            guard let result = result else { return }
            
             dispatchOnMain { [unowned self] in
                guard self.isActive else { return }
                
                switch result {
                case .data(let newNightscoutData):
                    self.updateInterface(withNightscoutData: newNightscoutData, error: nil)
                    self.updateComplication()
                    self.playAlarm(currentNightscoutData: newNightscoutData)
                case .error(let error):
                    self.updateInterface(withNightscoutData: nil, error: error)
                }
            }
        }
        
        paintCurrentBgData(currentNightscoutData: currentNightscoutData)
        self.playAlarm(currentNightscoutData: currentNightscoutData)
        
        if NightscoutCacheService.singleton.hasCurrentNightscoutDataPendingRequests {
            
            // show the activity indicator (hide the iob & arrow overlapping views); also hide the errors
            self.errorGroup.setHidden(true)
            self.iobLabel.setText(nil)
            self.cobLabel.setText(nil)
            self.deltaArrowLabel.setText(nil)
            
            self.activityIndicatorImage.setHidden(false)
            self.activityIndicatorImage.startAnimatingWithImages(in: NSRange(1...15), duration: 1.0, repeatCount: 0)
        }
    }
    
    fileprivate func playAlarm(currentNightscoutData : NightscoutData) {
        
        if AlarmRule.isAlarmActivated() {
            WKInterfaceDevice.current().play(.notification)
        }
    }
    
    fileprivate func updateComplication() {
        let complicationServer = CLKComplicationServer.sharedInstance()
        for complication in complicationServer.activeComplications! {
            complicationServer.reloadTimeline(for: complication)
        }
    }
    
    fileprivate func paintCurrentBgData(currentNightscoutData : NightscoutData) {
        
        self.bgLabel.setText(currentNightscoutData.sgv)
        self.bgLabel.setTextColor(UIColorChanger.getBgColor(currentNightscoutData.sgv))
        
        self.deltaLabel.setText(currentNightscoutData.bgdeltaString.cleanFloatValue)
        self.deltaArrowLabel.setText(currentNightscoutData.bgdeltaArrow)
        self.deltaLabel.setTextColor(UIColorChanger.getDeltaLabelColor(NSNumber(value : currentNightscoutData.bgdelta)))
        
        self.timeLabel.setText(currentNightscoutData.timeString)
        self.timeLabel.setTextColor(UIColorChanger.getTimeLabelColor(currentNightscoutData.time))
        
        self.batteryLabel.setText(currentNightscoutData.battery)
        self.cobLabel.setText(currentNightscoutData.cob)
        self.iobLabel.setText(currentNightscoutData.iob)
        
        // show raw values panel ONLY if configured so and we have a valid rawbg value!
        let isValidRawBGValue = UnitsConverter.toMgdl(currentNightscoutData.rawbg) > 0
        self.rawValuesGroup.setHidden(!UserDefaultsRepository.showRawBG.value || !isValidRawBGValue)
        self.rawbgLabel.setText(currentNightscoutData.rawbg)
        self.noiseLabel.setText(currentNightscoutData.noise)
    }
    
    func loadAndPaintChartData(forceRepaint : Bool) {
        
        // show a message if the today & yesterday data is missing, we're gonna load them now (will show on first install and when URI changes)
        if UserDefaultsRepository.baseUri.exists && NightscoutCacheService.singleton.isEmpty && NightscoutDataRepository.singleton.isEmpty {
            showMessage("Loading BG data...")
        }
        
        let newCachedTodaysBgValues: [BloodSugar]
        if NightscoutCacheService.singleton.hasTodaysBgDataPendingRequests {
           newCachedTodaysBgValues = NightscoutDataRepository.singleton.loadTodaysBgData()
        } else {
            newCachedTodaysBgValues = NightscoutCacheService.singleton.loadTodaysData { [unowned self] result in
                guard let result = result else { return }

                dispatchOnMain { [unowned self] in
                    guard self.isActive else { return }
                    
                    if case .data(let newTodaysData) = result {
                        self.cachedTodaysBgValues = newTodaysData
                        self.paintChartData(todaysData: newTodaysData, yesterdaysData: self.cachedYesterdaysBgValues, moveToLatestValue: true)
                    }
                }
            }
        }
        
        let newCachedYesterdaysBgValues: [BloodSugar]
        if NightscoutCacheService.singleton.hasYesterdaysBgDataPendingRequests {
            newCachedYesterdaysBgValues = NightscoutDataRepository.singleton.loadYesterdaysBgData()
        } else {
            newCachedYesterdaysBgValues = NightscoutCacheService.singleton.loadYesterdaysData { [unowned self] result in
                guard let result = result else { return }

                dispatchOnMain { [unowned self] in
                    guard self.isActive else { return }
                    
                    if case .data(let newYesterdaysData) = result {
                        self.cachedYesterdaysBgValues = newYesterdaysData
                        self.paintChartData(todaysData: self.cachedTodaysBgValues, yesterdaysData: newYesterdaysData, moveToLatestValue: false)
                    }
                }
            }
        }
        
        // this does a fast paint of eventually cached data
        if forceRepaint ||
            valuesChanged(newCachedTodaysBgValues: newCachedTodaysBgValues, newCachedYesterdaysBgValues: newCachedYesterdaysBgValues) {
            
            cachedTodaysBgValues = newCachedTodaysBgValues
            cachedYesterdaysBgValues = newCachedYesterdaysBgValues
            paintChartData(todaysData: cachedTodaysBgValues, yesterdaysData: cachedYesterdaysBgValues, moveToLatestValue: false)
        }
    }
    
    fileprivate func paintChartData(todaysData : [BloodSugar], yesterdaysData : [BloodSugar], moveToLatestValue : Bool) {
        
        let device = WKInterfaceDevice.current()
        let bounds = device.screenBounds
        
        let todaysDataWithPrediction = todaysData + PredictionService.singleton.nextHourGapped
        self.chartScene.paintChart(
            [todaysDataWithPrediction, yesterdaysData],
            newCanvasWidth: bounds.width * 6,
            maxYDisplayValue: CGFloat(UserDefaultsRepository.maximumBloodGlucoseDisplayed.value),
            moveToLatestValue: moveToLatestValue,
            displayDaysLegend: false,
            infoLabel: determineInfoLabel())
    }
    
    fileprivate func loadAndPaintCareData() {
        
        self.sensorAgeLabel.convertToAge(prefix: "S ", time: NightscoutCacheService.singleton.getSensorChangeTime(), hoursUntilWarning: 24 * 9, hoursUntilCritical: 24 * 13)
        self.cannulaAgeLabel.convertToAge(prefix: "C ", time:  NightscoutCacheService.singleton.getCannulaChangeTime(),
                                          hoursUntilWarning: 24 * 2 - 2, hoursUntilCritical: 24 * 3 - 2)
        self.batteryAgeLabel.convertToAge(prefix: "B ", time:  NightscoutCacheService.singleton.getPumpBatteryChangeTime(),
                                          hoursUntilWarning: 24 * 28, hoursUntilCritical: 24 * 30)
        let deviceStatusData = NightscoutCacheService.singleton.getDeviceStatusData({ [unowned self] result in
            self.paintDeviceStatusData(deviceStatusData: result)
        })
        
        self.paintDeviceStatusData(deviceStatusData: deviceStatusData)
    }
    
    func paintDeviceStatusData(deviceStatusData: DeviceStatusData) {
        self.activeProfileLabel.setText(deviceStatusData.activePumpProfile)
        if deviceStatusData.temporaryBasalRate != "" &&
            deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes() > 0 {
            
            self.temporaryBasalLabel.setText("TB \(deviceStatusData.temporaryBasalRate)% \(deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes())m")
        } else {
            self.temporaryBasalLabel.setText("TB --")
        }
        
        let temporaryTargetData = NightscoutCacheService.singleton.getTemporaryTargetData()
        if temporaryTargetData.activeUntilDate.remainingMinutes() > 0 {
            self.temporaryTargetLabel.setText("TT \(temporaryTargetData.targetTop) \(temporaryTargetData.activeUntilDate.remainingMinutes())m")
        } else {
            self.temporaryTargetLabel.setText("TT --")
        }
    }

    func determineInfoLabel() -> String {
        
        if !AlarmRule.isSnoozed() {
            if let alarmReason = AlarmRule.getAlarmActivationReason() {
                return  alarmReason
            } else {
                return ""
            }
        }
        
        return String(format: NSLocalizedString("Snoozed %dmin", comment: "Snoozed duration on watch"), AlarmRule.getRemainingSnoozeMinutes())
    }
    
    func sendNightSafeRequest() {
        
        // request phone settings for determining to show the night safe indicator
        RequestNightSafeMessage().send { [weak self] (response: ResponseNightSafeMessage) in
            dispatchOnMain {
                guard let self = self else { return }
                guard self.isActive else { return }
                
                // show the night safe indicator if phone is active & lock screen is ON
                self.nightSafeIndicator.setHidden(
                    !(response.value.isPhoneActive && response.value.isScreenLockActive)
                )
                self.nightSafeIndicator.setAlpha(CGFloat(response.value.volumeLevel))
                
                delay(2) { [weak self] in
                    guard let self = self else { return }
                    guard self.isActive else { return }
                    self.animate(withDuration: 0.8) { [weak self] in
                        self?.nightSafeIndicator.setHidden(true)
                    }
                }
            }
        }
    }

}

@available(watchOSApplicationExtension 3.0, *)
extension InterfaceController {
    
    // obtain the InterfaceController on main thread if app state is active
    static func onMain(_ closure: @escaping (InterfaceController) -> Void) {
        
        guard let interfaceController = WKExtension.shared().rootInterfaceController as? InterfaceController else {
            return
        }
        
        dispatchOnMain {
            guard WKExtension.shared().applicationState == .active else { return }
            guard interfaceController.isActive else { return }
            closure(interfaceController)
        }
    }
}
