//
//  MainViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 02.01.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit
import MediaPlayer
import WatchConnectivity
import SpriteKit
import XLActionController

class MainViewController: UIViewController, SlideToSnoozeDelegate {

    @IBOutlet weak var bgLabel: UILabel!
    @IBOutlet weak var deltaLabel: UILabel!
    @IBOutlet weak var deltaArrowsLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var lastUpdateLabel: UILabel!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var cobLabel: UILabel!
    @IBOutlet weak var iobLabel: UILabel!
    @IBOutlet weak var spriteKitView: UIView!
    @IBOutlet weak var errorPanelView: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var rawValuesPanel: GroupedLabelsView!
    @IBOutlet weak var bgStackView: UIStackView!
    
    @IBOutlet weak var actionsMenuButton: UIButton!
    @IBOutlet weak var actionsMenuButtonPanelView: UIView!
    @IBOutlet weak var statsPanelView: BasicStatsPanelView!
    @IBOutlet weak var slideToSnoozeView: SlideToSnoozeView!
    @IBOutlet weak var slideToSnoozeViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var cannulaAgeLabel: UILabel!
    @IBOutlet weak var sensorAgeLabel: UILabel!
    @IBOutlet weak var batteryAgeLabel: UILabel!
    @IBOutlet weak var activeProfileLabel: UILabel!
    @IBOutlet weak var temporaryBasalLabel: UILabel!
    @IBOutlet weak var temporaryTargetLabel: UILabel!
    
    // currently presented bedside view controller instance
    private var bedsideViewController: BedsideViewController?
    
    // the way that has already been moved during a pan gesture
    var oldXTranslation : CGFloat = 0
    
    var chartScene = ChartScene(size: CGSize(width: 320, height: 280), newCanvasWidth: 1024)
    // timer to check continuously for new bgValues
    var timer = Timer()
    // check every 30 Seconds whether new bgvalues should be retrieved
    let timeInterval: TimeInterval = 30.0
    
    // basic stats for the last 24 hours
    var basicStats: BasicStats?
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the ChartScene
        chartScene = ChartScene(size: CGSize(width: spriteKitView.bounds.width, height: spriteKitView.bounds.height),
                                newCanvasWidth: self.maximumDeviceTextureWidth())
        let skView = spriteKitView as! SKView
        skView.presentScene(chartScene)
        
        // Register Gesture Recognizer so that the user can scroll
        // through the charts
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(MainViewController.panGesture(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(MainViewController.pinchGesture(_:)))
        
        skView.addGestureRecognizer(panGesture)
        skView.addGestureRecognizer(pinchGesture)
        
        errorPanelView.isHidden = true
        
        // decide where to present the raw bg panel, depending on the device screen size: for small screens (under 4.7 inches) the raw bg panel is stacked under the bg label; for larger screens, the raw bg panel is near (right side of) the bg label
        let screenSize = UIScreen.main.bounds.size
        let height = max(screenSize.width, screenSize.height)
        let isLargeEnoughScreen = height >= 667 // 4.7 inches or larger (iPhone 6, etc.)
        rawValuesPanel.axis = isLargeEnoughScreen ? .vertical : .horizontal
        bgStackView.axis = isLargeEnoughScreen ? .horizontal : .vertical
        
        actionsMenuButton.tintColor = UIColor.gray
        let actionImage = UIImage(named: "Action")?.withRenderingMode(.alwaysTemplate)
        actionsMenuButton.setImage(actionImage, for: .normal)
        actionsMenuButton.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        actionsMenuButtonPanelView.backgroundColor = .black
        
        // stop timer when app enters in background, start is again when becomes active
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // call first "UIApplicationWillEnterForeground" event by hand, it is not sent when the app starts (just registered for the event)
        prepareForEnteringForeground()

        // liste to alarm snoozing & play/stop alarm accordingly
        AlarmRule.onSnoozeTimestampChanged = { [weak self] in
            self?.evaluateAlarmActivationState()
        }
        
        UserDefaultsRepository.upperBound.observeChanges { [weak self] _ in
            self?.updateBasicStats()
        }
        UserDefaultsRepository.lowerBound.observeChanges { [weak self] _ in
            self?.updateBasicStats()
        }
        
        // show nightscout on long press of action button
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(MainViewController.longPressGesture(_:)))
        self.actionsMenuButton.addGestureRecognizer(longPressGestureRecognizer)
        
        // show nightscout on force press of action button
        let forcePressGestureRecognizer = DeepPressGestureRecognizer(target: self, action: #selector(MainViewController.deepPressGesture(_:)))
        self.actionsMenuButton.addGestureRecognizer(forcePressGestureRecognizer)
        
        slideToSnoozeView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        showHideRawBGPanel()

        // show/hide the stats panel, using user preference value
        let statsShouldBeHidden = !UserDefaultsRepository.showStats.value
        if statsPanelView.isHidden != statsShouldBeHidden {
            statsPanelView.isHidden = statsShouldBeHidden
            
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            if !statsPanelView.isHidden {
                DispatchQueue.main.async { [unowned self] in
                    self.statsPanelView.updateModel()
                }
            }
        }
        
        actionsMenuButtonPanelView.isHidden = AlarmRule.areAlertsGenerallyDisabled.value
        slideToSnoozeView.isHidden = AlarmRule.areAlertsGenerallyDisabled.value
        if AlarmRule.areAlertsGenerallyDisabled.value {
            slideToSnoozeViewHeightConstraint.constant = 0
        } else {
            slideToSnoozeViewHeightConstraint.constant = 80
        }
        slideToSnoozeView.setNeedsLayout()
        slideToSnoozeView.layoutIfNeeded()
    }
        
    override func viewDidAppear(_ animated: Bool) {
        
        // Remind the user with every new version, that this is a
        // volunteers project without any warranty!
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        showAcceptDeclineAlert(title: "Disclaimer!", message:
            "Don't use this App for medical decisions! " +
            "It comes with absolutely NO WARRANTY. " +
            "It is maintained by volunteers only. " +
            "Use it at your own risk!",
                  showOnceKey: "showedWarningIn\(versionNumber)")
        
        // Start immediately so that the current time gets displayed at once
        // And the alarm can play if needed
        doPeriodicUpdate(forceRepaint: true)
        
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        
        chartScene.size = CGSize(width: spriteKitView.bounds.width, height: spriteKitView.bounds.height)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // keep the nightscout button round
        actionsMenuButton.layer.cornerRadius = actionsMenuButton.bounds.size.width / 2
        actionsMenuButtonPanelView.layer.cornerRadius = actionsMenuButtonPanelView.bounds.size.width / 2
        
        DispatchQueue.main.async { [unowned self] in
            self.chartScene.size = CGSize(width: self.spriteKitView.bounds.width, height: self.spriteKitView.bounds.height)
            self.loadAndPaintChartData(forceRepaint: true)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
 
        chartScene.stopSwipeAction()
    }
    
    @objc func panGesture(_ recognizer : UIPanGestureRecognizer) {
        
        if recognizer.state == UIGestureRecognizer.State.began {
            oldXTranslation = 0

            // The user just touched the display
            // So we use this to stop eventually running actions
            chartScene.stopSwipeAction()
        }
        let translation = recognizer.translation(in: spriteKitView)

        chartScene.draggedByATouch(translation.x - oldXTranslation)
        oldXTranslation = translation.x
        
        if (recognizer.state == UIGestureRecognizer.State.ended) {
            let velocity = recognizer.velocity(in: spriteKitView)
            
            if (velocity.x < -100) {
                // Left Swipe detected
                chartScene.swipeChart(velocity.x)
            } else if (velocity.x > 100) {
                // Right Swipe detected
                chartScene.swipeChart(velocity.x)
            }
        }
    }
    
    // This gesture is used to zoom in and out by changing the maximum
    // Blood Glucose value that is displayed in the chart.
    @objc func pinchGesture(_ recognizer : UIPinchGestureRecognizer) {
        
        if recognizer.state == UIGestureRecognizer.State.ended {
            chartScene.scale(recognizer.scale, keepScale: true, infoLabelText: "")
        } else {
            chartScene.scale(recognizer.scale, keepScale: false, infoLabelText: "")
        }        
    }
    
    @objc func longPressGesture(_ recognizer : UILongPressGestureRecognizer) {
        
        guard recognizer.state == UIGestureRecognizer.State.recognized else {
            return
        }
        
        showNightscout()
    }
    
    @objc func deepPressGesture(_ recognizer : DeepPressGestureRecognizer) {
        
        guard recognizer.state == UIGestureRecognizer.State.recognized else {
            return
        }
        
        showNightscout()
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    // MARK: Notification
    
    @objc func applicationWillResignActive(_ notification: NSNotification) {
        AlarmSound.stop()
    }
    
    @objc func applicationDidEnterBackground(_ notification: Notification) {
        timer.invalidate()
    }
    
    @objc func applicationWillEnterForeground(_ notification: Notification) {
        prepareForEnteringForeground()
    }

    fileprivate func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: timeInterval,
                                     target: self,
                                     selector: #selector(MainViewController.timerDidEnd(_:)),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    fileprivate func prepareForEnteringForeground() {
        
        // If there is already a snooze active => we don't have to fear that an alarm
        // would be played.
        if !AlarmRule.isSnoozed() {
            // snooze the alarm for 15 Seconds in order to retrieve new data
            // before playing alarm
            // Otherwise it could be the case that the app immediately plays
            // an alarm sound without giving the app the chance to reload
            // current data
            AlarmRule.snoozeSeconds(15)
        }
        
        startTimer()
        doPeriodicUpdate(forceRepaint: true)
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
        self.bedsideViewController?.updateAlarmInfo()
    }
    
    // check whether new Values should be retrieved
    @objc func timerDidEnd(_ timer:Timer) {
        self.doPeriodicUpdate(forceRepaint: false)
    }
    
    func doPeriodicUpdate(forceRepaint: Bool) {
        
        self.paintCurrentTime()
        // paint here is need if the server doesn't respond
        // => in that case the user has to know that the values are old!
        self.loadAndPaintCurrentBgData()
        self.loadAndPaintChartData(forceRepaint: forceRepaint)
        self.loadAndPaintCareData()
    }
    
    func slideToSnoozeDelegateDidFinish(_ sender: SlideToSnoozeView) {
        showSnoozePopup()
    }
    
    @IBAction func showActionsMenu(_ sender: AnyObject) {
        
        let actionController = MenuActionController()
        actionController.addAction(Action(MenuActionData(title:  NSLocalizedString("Open your Nightscout site", comment: "Link to NS site"), image: UIImage(named: "Nightscout")!.withRenderingMode(.alwaysTemplate)), style: .default) { [unowned self] _ in
            
            self.showNightscout()
        })
        actionController.addAction(Action(MenuActionData(title:  NSLocalizedString("Fullscreen monitor", comment: "Fullscreen monitor"), image: UIImage(named: "Fullscreen")!.withRenderingMode(.alwaysTemplate)), style: .default) {  [unowned self] _ in
            self.showFullscreenMonitor()
        })
        
        present(actionController, animated: true) {
            actionController.view.tintColor = UIColor.white//.withAlphaComponent(0.7)
        }
    }
    
    func showNightscout() {
        let nightscoutInitialViewController = UIStoryboard(name: "Nightscout", bundle: Bundle.main).instantiateInitialViewController()!
        nightscoutInitialViewController.modalPresentationStyle = .fullScreen
        self.present(nightscoutInitialViewController, animated: true, completion: nil)
    }
    
    func showFullscreenMonitor() {
        self.bedsideViewController = BedsideViewController.instantiate()
        self.bedsideViewController?.modalPresentationStyle = .fullScreen
        self.present(self.bedsideViewController!, animated: true)
        
        // initiate a periodic update for feeding fresh data to presented view controller
        self.doPeriodicUpdate(forceRepaint: false)
    }
        
    public func updateSnoozeButtonText() {

        let isSmallDevice = DeviceSize().isSmall
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        
        let titleAttributes: [NSAttributedString.Key : Any] = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: isSmallDevice ? 24 : 27),
            NSAttributedString.Key.paragraphStyle: style
        ]
        var title = NSMutableAttributedString(string: NSLocalizedString("snooze", comment: "Text of snooze button"), attributes: titleAttributes)
        var subtitle = AlarmRule.getAlarmActivationReason(ignoreSnooze: true)
        var subtitleColor: UIColor = (subtitle != nil) ? .red : .white
        var showSubtitle = true
        
        if subtitle == nil {
            
            if AlarmRule.isLowPredictionEnabled.value {
                
                // no alarm, but maybe we'll show a low prediction warning...
                if let minutesToLow = PredictionService.singleton.minutesTo(low: AlarmRule.alertIfBelowValue.value), minutesToLow > 0 {
                    subtitle = String(format: NSLocalizedString("Low Predicted in %dmin", comment: "Show low prediction warning"), minutesToLow)
                    subtitleColor = .yellow
                }
            }
        }

        if AlarmRule.isSnoozed() {
            let remaininingSnoozeMinutes = AlarmRule.getRemainingSnoozeMinutes()
            let titleString = String(format: NSLocalizedString("Snoozed for %dmin", comment: "Snoozed duration in main page"), remaininingSnoozeMinutes)
            title = NSMutableAttributedString(string: titleString, attributes: titleAttributes)
            
            // show alert reason message if less than 5 minutes of snoozing (to be prepared!)
            showSubtitle = remaininingSnoozeMinutes < 5
        }
        
        if let subtitle = subtitle, showSubtitle {
            
            let messageAttributes: [NSAttributedString.Key : Any] = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: isSmallDevice ? 14 : 16),
                NSAttributedString.Key.foregroundColor: subtitleColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let attString = NSMutableAttributedString()
            attString.append(title)
            attString.append(NSAttributedString(string: "\n"))
            attString.append(NSAttributedString(string: subtitle, attributes: messageAttributes))
            
            slideToSnoozeView.setAttributedTitle(title: attString)
        } else {
            slideToSnoozeView.setAttributedTitle(title: title)
        }
    }
    
    fileprivate func paintCurrentTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        self.timeLabel.text = formatter.string(from: Date())
    }
    
    fileprivate func loadAndPaintCurrentBgData() {
        
        let currentNightscoutData = NightscoutCacheService.singleton.loadCurrentNightscoutData { [unowned self] result in
            
            // play alarm if activated or stop otherwise
            self.evaluateAlarmActivationState()

            // update app badge
            if UserDefaultsRepository.showBGOnAppBadge.value {
                UIApplication.shared.setCurrentBGValueOnAppBadge()
            }
            
            guard let result = result else {
                return
            }
            
            switch result {
            case .error(let error):
                self.errorLabel.text = "❌ \(error.localizedDescription)"
                self.errorLabel.textColor = .red
                self.errorPanelView.isHidden = false
            case .data(let newNightscoutData):
                self.errorPanelView.isHidden = true
                self.paintCurrentBgData(currentNightscoutData: newNightscoutData)
                self.bedsideViewController?.currentNightscoutData = newNightscoutData
                
                WatchService.singleton.sendToWatchCurrentNightwatchData()
            }
        }
        
        paintCurrentBgData(currentNightscoutData: currentNightscoutData)
        self.bedsideViewController?.currentNightscoutData = currentNightscoutData
    }
    
    fileprivate func paintCurrentBgData(currentNightscoutData : NightscoutData) {
        
        DispatchQueue.main.async(execute: {
            if currentNightscoutData.sgv == "---" {
                self.bgLabel.text = "---"
            } else {
                self.bgLabel.text = currentNightscoutData.sgv
            }
            self.bgLabel.textColor = UIColorChanger.getBgColor(currentNightscoutData.sgv)
            
            self.deltaLabel.text = currentNightscoutData.bgdeltaString.cleanFloatValue
            self.deltaArrowsLabel.text = currentNightscoutData.bgdeltaArrow
            self.deltaLabel.textColor = UIColorChanger.getDeltaLabelColor(NSNumber(value: currentNightscoutData.bgdelta))
            self.deltaArrowsLabel.textColor = UIColorChanger.getDeltaLabelColor(NSNumber(value: currentNightscoutData.bgdelta))
            
            self.lastUpdateLabel.text = currentNightscoutData.timeString
            self.lastUpdateLabel.textColor = UIColorChanger.getTimeLabelColor(currentNightscoutData.time)
            
            self.batteryLabel.text = currentNightscoutData.battery
            self.iobLabel.text = currentNightscoutData.iob
            self.cobLabel.text = currentNightscoutData.cob
            
            self.showHideRawBGPanel(currentNightscoutData)
            self.rawValuesPanel.label.text = currentNightscoutData.noise
            self.rawValuesPanel.highlightedLabel.text = currentNightscoutData.rawbg
        })
    }
    
    fileprivate func loadAndPaintChartData(forceRepaint : Bool) {
        
        let newCachedTodaysBgValues = NightscoutCacheService.singleton.loadTodaysData { [unowned self] result in
            guard let result = result else { return }
         
            if case .data(let newTodaysData) = result {
                let cachedYesterdaysData = NightscoutCacheService.singleton.getYesterdaysBgData()
                self.paintChartData(todaysData: newTodaysData, yesterdaysData: cachedYesterdaysData)
                self.updateBasicStats()
            }
        }
        
        let newCachedYesterdaysBgValues = NightscoutCacheService.singleton.loadYesterdaysData { [unowned self] result in
            guard let result = result else { return }
            
            if case .data(let newYesterdaysData) = result {
                let cachedTodaysBgData = NightscoutCacheService.singleton.getTodaysBgData()
                self.paintChartData(todaysData: cachedTodaysBgData, yesterdaysData: newYesterdaysData)
                self.updateBasicStats()
            }
        }
        
        // this does a fast paint of eventually cached data
        if forceRepaint ||
            NightscoutCacheService.singleton.valuesChanged() {
            
            paintChartData(todaysData: newCachedTodaysBgValues, yesterdaysData: newCachedYesterdaysBgValues)
        }
    }
    
    fileprivate func loadAndPaintCareData() {
        
        self.sensorAgeLabel.convertToAge(prefix: "SAGE ", time: NightscoutCacheService.singleton.getSensorChangeTime(), hoursUntilWarning: 24 * 9, hoursUntilCritical: 24 * 13)
        self.cannulaAgeLabel.convertToAge(prefix: "CAGE ", time:  NightscoutCacheService.singleton.getCannulaChangeTime(),
                                          hoursUntilWarning: 24 * 2 - 2, hoursUntilCritical: 24 * 3 - 2)
        self.batteryAgeLabel.convertToAge(prefix: "BAT ", time:  NightscoutCacheService.singleton.getPumpBatteryChangeTime(),
                                          hoursUntilWarning: 24 * 28, hoursUntilCritical: 24 * 30)
        let deviceStatusData = NightscoutCacheService.singleton.getDeviceStatusData { [unowned self] result in
            self.paintDeviceStatusData(deviceStatusData: result)
        }
        
        self.paintDeviceStatusData(deviceStatusData: deviceStatusData)
    }
    
    fileprivate func paintDeviceStatusData(deviceStatusData : DeviceStatusData) -> Void {
    
        self.activeProfileLabel.text = deviceStatusData.activePumpProfile;
        if deviceStatusData.temporaryBasalRate != "" &&
            deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes() > 0 {
            
            self.temporaryBasalLabel.text = "TB \(deviceStatusData.temporaryBasalRate)% \(deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes())m"
        } else {
            self.temporaryBasalLabel.text = "TB --"
        }
        
        let temporaryTargetData = NightscoutCacheService.singleton.getTemporaryTargetData()
        if temporaryTargetData.activeUntilDate.remainingMinutes() > 0 {
            self.temporaryTargetLabel.text = "TT \(temporaryTargetData.targetTop) \(temporaryTargetData.activeUntilDate.remainingMinutes())m"
        } else {
            self.temporaryTargetLabel.text = "TT --"
        }
    }

    fileprivate func paintChartData(todaysData : [BloodSugar], yesterdaysData : [BloodSugar]) {
        
        let todaysDataWithPrediction = todaysData + PredictionService.singleton.nextHourGapped
        
        self.chartScene.paintChart(
            [todaysDataWithPrediction, yesterdaysData],
            newCanvasWidth: self.maximumDeviceTextureWidth(),
            maxYDisplayValue: CGFloat(UserDefaultsRepository.maximumBloodGlucoseDisplayed.value),
            moveToLatestValue: true)
    }
    
    fileprivate func showHideRawBGPanel(_ nightscoutData: NightscoutData? = nil) {
        
        let currentNightscoutData = nightscoutData ?? NightscoutCacheService.singleton.getCurrentNightscoutData()
        let isValidRawBGValue = UnitsConverter.toMgdl(currentNightscoutData.rawbg) > 0

        // show raw values panel ONLY if configured so and we have a valid rawbg value!
        self.rawValuesPanel.isHidden = !UserDefaultsRepository.showRawBG.value || !isValidRawBGValue
    }
    
    fileprivate func updateBasicStats() {
        
        // update the UI
//        statsLabel.text = "A1c: \(String(format: "%.1f", basicStats!.a1c))%, in: \(String(format: "%.1f", basicStats!.inRangeValuesPercentage * 100))%"
        if !statsPanelView.isHidden {
            statsPanelView.updateModel()
        }
    }
}
