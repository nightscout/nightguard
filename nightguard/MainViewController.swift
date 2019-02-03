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

class MainViewController: UIViewController {
    
    @IBOutlet weak var bgLabel: UILabel!
    @IBOutlet weak var deltaLabel: UILabel!
    @IBOutlet weak var deltaArrowsLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var lastUpdateLabel: UILabel!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var iobLabel: UILabel!
    @IBOutlet weak var snoozeButton: UIButton!
    @IBOutlet weak var screenlockSwitch: UISwitch!
    @IBOutlet weak var volumeContainerView: UIView!
    @IBOutlet weak var spriteKitView: UIView!
    @IBOutlet weak var errorPanelView: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var rawValuesPanel: GroupedLabelsView!
    @IBOutlet weak var bgStackView: UIStackView!
    
    @IBOutlet weak var nightscoutButton: UIButton!
    // the way that has already been moved during a pan gesture
    var oldXTranslation : CGFloat = 0
    
    var chartScene = ChartScene(size: CGSize(width: 320, height: 280), newCanvasWidth: 1024)
    // timer to check continuously for new bgValues
    var timer = Timer()
    // check every 30 Seconds whether new bgvalues should be retrieved
    let timeInterval: TimeInterval = 30.0
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Embed the Volume Slider View
        // This way the system volume can be
        // controlled by the user
        let volumeView = MPVolumeView(frame: volumeContainerView.bounds)
        volumeView.backgroundColor = UIColor.black
        volumeView.tintColor = UIColor.gray
        volumeContainerView.addSubview(volumeView)
        // add an observer to resize the MPVolumeView when displayed on e.g. 4.7" iPhone
        volumeContainerView.addObserver(self, forKeyPath: "bounds", options: [], context: nil)
        
        snoozeButton.titleLabel?.numberOfLines = 0
        snoozeButton.titleLabel?.lineBreakMode = .byWordWrapping
        snoozeButton.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        
        restoreGuiState()
        paintScreenLockSwitch()
        
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
        
        nightscoutButton.tintColor = UIColor.white
        let nightscoutImage = UIImage(named: "Nightscout")?.withRenderingMode(.alwaysTemplate)
        nightscoutButton.setImage(nightscoutImage, for: .normal)
        nightscoutButton.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        
        // stop timer when app enters in background, start is again when becomes active
        NotificationCenter.default.addObserver(self, selector: #selector(UIApplicationDelegate.applicationDidEnterBackground(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(UIApplicationDelegate.applicationWillResignActive(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(UIApplicationDelegate.applicationWillEnterForeground(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        
        // call first "UIApplicationWillEnterForeground" event by hand, it is not sent when the app starts (just registered for the event)
        prepareForEnteringForeground()
        
        // keep this instance in app delegate
        (UIApplication.shared.delegate as? AppDelegate)?.mainViewController = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        showHideRawBGPanel()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
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
        nightscoutButton.layer.cornerRadius = nightscoutButton.bounds.size.width / 2
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
 
        chartScene.stopSwipeAction()
    }
    
    @objc func panGesture(_ recognizer : UIPanGestureRecognizer) {
        
        if recognizer.state == UIGestureRecognizerState.began {
            oldXTranslation = 0

            // The user just touched the display
            // So we use this to stop eventually running actions
            chartScene.stopSwipeAction()
        }
        let translation = recognizer.translation(in: spriteKitView)

        chartScene.draggedByATouch(translation.x - oldXTranslation)
        oldXTranslation = translation.x
        
        if (recognizer.state == UIGestureRecognizerState.ended) {
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
        
        if recognizer.state == UIGestureRecognizerState.ended {
            chartScene.scale(recognizer.scale, keepScale: true, infoLabelText: "")
        } else {
            chartScene.scale(recognizer.scale, keepScale: false, infoLabelText: "")
        }
    }
    
    // Resize the MPVolumeView when the parent view changes
    // This is needed on an e.g. 4,7" iPhone. Otherwise the MPVolumeView would be too small
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        let volumeView = MPVolumeView(frame: volumeContainerView.bounds)
        volumeView.backgroundColor = UIColor.black
        volumeView.tintColor = UIColor.gray

        for view in volumeContainerView.subviews {
            view.removeFromSuperview()
        }
        volumeContainerView.addSubview(volumeView)
    }
    
    fileprivate func restoreGuiState() {
        
        screenlockSwitch.isOn = GuiStateRepository.singleton.loadScreenlockSwitchState()
        doScreenlockAction(self)
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
            self.updateSnoozeButtonText()
        }
        
        startTimer()
        doPeriodicUpdate(forceRepaint: true)
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
    }
    
    fileprivate func paintScreenLockSwitch() {
        screenlockSwitch.isOn = UIApplication.shared.isIdleTimerDisabled
    }
    
    @IBAction func doSnoozeAction(_ sender: AnyObject) {
        
        // stop the alarm immediatly here not to disturb others
        AlarmSound.muteVolume()
        showSnoozePopup()
        // For safety reasons: Unmute sound after 1 minute
        // This prevents an unlimited snooze if the snooze button was touched accidentally.
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0, execute: {
            AlarmSound.unmuteVolume()
        })
    }
    
    fileprivate func showSnoozePopup() {
        
        // create the snooze popup view
        if let snoozeAlarmNavigationController = self.storyboard?.instantiateViewController(
            withIdentifier: "snoozeAlarmNavigationController")  {
            self.present(snoozeAlarmNavigationController, animated: true, completion: nil)
        }
    }
    
    public func updateSnoozeButtonText() {

        var title = "Snooze"
        var subtitle = AlarmRule.getAlarmActivationReason(ignoreSnooze: true)
        var subtitleColor: UIColor = (subtitle != nil) ? .red : .white
        var showSubtitle = true
        
        if subtitle == nil {
            
            // no alarm, but maybe we'll show a low prediction warning...
            if let minutesToLow = PredictionService.singleton.minutesTo(low: AlarmRule.alertIfBelowValue.value), minutesToLow > 0 {
                subtitle = "Low Predicted in \(minutesToLow)min"
                subtitleColor = .yellow
            }
        }

        if AlarmRule.isSnoozed() {
            let remaininingSnoozeMinutes = AlarmRule.getRemainingSnoozeMinutes()
            title = "Snoozed for \(remaininingSnoozeMinutes)min"
            
            // show alert reason message if less than 5 minutes of snoozing (to be prepared!)
            showSubtitle = remaininingSnoozeMinutes < 5
        }
        
        if let subtitle = subtitle, showSubtitle {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = .byWordWrapping
            
            let titleAttributes: [NSAttributedStringKey : Any] = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 32),
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let messageAttributes: [NSAttributedStringKey : Any] = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                NSAttributedString.Key.foregroundColor: subtitleColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let attString = NSMutableAttributedString()
            attString.append(NSAttributedString(string: title, attributes: titleAttributes))
            attString.append(NSAttributedString(string: "\n"))
            attString.append(NSAttributedString(string: subtitle, attributes: messageAttributes))
            
            snoozeButton.setAttributedTitle(attString, for: .normal)
        } else {
            snoozeButton.setAttributedTitle(nil, for: .normal)
            snoozeButton.setTitle(title, for: .normal)
        }
    }
    
    @IBAction func doScreenlockAction(_ sender: AnyObject) {
        if screenlockSwitch.isOn {
            UIApplication.shared.isIdleTimerDisabled = true
            GuiStateRepository.singleton.storeScreenlockSwitchState(true)
            
            displayScreenlockInfoMessageOnlyOnce()
        } else {
            UIApplication.shared.isIdleTimerDisabled = false
            GuiStateRepository.singleton.storeScreenlockSwitchState(false)
        }
    }
    
    fileprivate func displayScreenlockInfoMessageOnlyOnce() {
        let screenlockMessageShowed = UserDefaults.standard.bool(forKey: "screenlockMessageShowed")
        
        if !screenlockMessageShowed {
            
            let alertController = UIAlertController(title: "Keep the screen active", message: "Turn this switch to disable the screenlock and prevent the app to get stopped!", preferredStyle: .alert)
            let actionOk = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(actionOk)
            present(alertController, animated: true, completion: nil)
            
            UserDefaults.standard.set(true, forKey: "screenlockMessageShowed")
        }
    }
    
    fileprivate func paintCurrentTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        self.timeLabel.text = formatter.string(from: Date())
    }
    
    fileprivate func loadAndPaintCurrentBgData() {
        
        let currentNightscoutData = NightscoutCacheService.singleton.loadCurrentNightscoutData { [unowned self] result in
            
            // play alarm if activated
            if AlarmRule.isAlarmActivated() {
                AlarmSound.play()
            } else {
                AlarmSound.stop()
            }
            self.updateSnoozeButtonText()

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
                
                WatchService.singleton.sendToWatchCurrentNightwatchData()
            }
        }
        
        paintCurrentBgData(currentNightscoutData: currentNightscoutData)
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
            }
        }
        
        let newCachedYesterdaysBgValues = NightscoutCacheService.singleton.loadYesterdaysData { [unowned self] result in
            guard let result = result else { return }
            
            if case .data(let newYesterdaysData) = result {
                let cachedTodaysBgData = NightscoutCacheService.singleton.getTodaysBgData()
                self.paintChartData(todaysData: cachedTodaysBgData, yesterdaysData: newYesterdaysData)
            }
        }
        
        // this does a fast paint of eventually cached data
        if forceRepaint ||
            NightscoutCacheService.singleton.valuesChanged() {
            
            paintChartData(todaysData: newCachedTodaysBgValues, yesterdaysData: newCachedYesterdaysBgValues)
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
}
