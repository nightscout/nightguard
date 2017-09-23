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
    @IBOutlet weak var snoozeButton: UIButton!
    @IBOutlet weak var screenlockSwitch: UISwitch!
    @IBOutlet weak var volumeContainerView: UIView!
    @IBOutlet weak var spriteKitView: UIView!

    // the way that has already been moved during a pan gesture
    var oldXTranslation : CGFloat = 0
    
    var chartScene = ChartScene(size: CGSize(width: 320, height: 280), newCanvasWidth: 1024)
    // timer to check continuously for new bgValues
    var timer = Timer()
    // check every 5 Seconds whether new bgvalues should be retrieved
    let timeInterval:TimeInterval = 5.0
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // snooze the alarm for 15 Seconds in order to retrieve new data
        // before playing alarm
        AlarmRule.snoozeSeconds(15)
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
        
        checkForNewValuesFromNightscoutServer()
        restoreGuiState()
        
        paintScreenLockSwitch()
        paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
        
        // Start the timer to retrieve new bgValues
        timer = Timer.scheduledTimer(timeInterval: timeInterval,
                                                       target: self,
                                                       selector: #selector(MainViewController.timerDidEnd(_:)),
                                                       userInfo: nil,
                                                       repeats: true)
        // Start immediately so that the current time gets display at once
        // And the alarm can play if needed
        timerDidEnd(timer)
        
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        
        chartScene.size = CGSize(width: spriteKitView.bounds.width, height: spriteKitView.bounds.height)
        
        let historicBgData = BgDataHolder.singleton.getTodaysBgData()
        // only if currentDay values are there, it makes sence to display them here
        // otherwise, wait to get this data and display it using the running timer
        if historicBgData.count > 0 {
            YesterdayBloodSugarService.singleton.getYesterdaysValuesTransformedToCurrentDay() { yesterdaysValues in
            
                self.chartScene.paintChart(
                    [historicBgData, yesterdaysValues],
                    newCanvasWidth: self.maximumDeviceTextureWidth(),
                    maxYDisplayValue: CGFloat(UserDefaultsRepository.readMaximumBloodGlucoseDisplayed()),
                    moveToLatestValue: true)
            }
        }
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
            chartScene.scale(recognizer.scale, keepScale: true)
        } else {
            chartScene.scale(recognizer.scale, keepScale: false)
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
    
    // check whether new Values should be retrieved
    @objc func timerDidEnd(_ timer:Timer) {
        
        checkForNewValuesFromNightscoutServer()
        if AlarmRule.isAlarmActivated(BgDataHolder.singleton.getCurrentBgData(), bloodValues: BgDataHolder.singleton.getTodaysBgData()) {
            // Play the sound only if foreground => otherwise this won't work at all
            // and the sound will only play right when opening the application :-/
            let state = UIApplication.shared.applicationState
            if state == UIApplicationState.active {
                AlarmSound.play()
            }
        } else {
            AlarmSound.stop()
        }
        updateSnoozeButtonText()
        
        paintCurrentTime()
        // paint here is need if the server doesn't respond
        // => in that case the user has to know that the values are old!
        paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
    }
    
    fileprivate func checkForNewValuesFromNightscoutServer() {
        
        YesterdayBloodSugarService.singleton.warmupCache()
        if BgDataHolder.singleton.getCurrentBgData().isOlderThan5Minutes() {
            
            readNewValuesFromNightscoutServer()
        } else {
            paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
        }
    }
    
    fileprivate func readNewValuesFromNightscoutServer() {
        
        NightscoutService.singleton.readCurrentDataForPebbleWatch({(nightscoutData) -> Void in
            BgDataHolder.singleton.setCurrentBgData(nightscoutData)
            self.paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
            NightscoutDataRepository.singleton.storeCurrentNightscoutData(nightscoutData)
        })
        NightscoutService.singleton.readTodaysChartData({(historicBgData) -> Void in
            
            BgDataHolder.singleton.setTodaysBgData(historicBgData)
            if BgDataHolder.singleton.hasNewValues {
                YesterdayBloodSugarService.singleton.getYesterdaysValuesTransformedToCurrentDay() { yesterdayValues in
                    self.chartScene.paintChart(
                        [historicBgData, yesterdayValues],
                        newCanvasWidth: self.maximumDeviceTextureWidth(),
                        maxYDisplayValue: CGFloat(UserDefaultsRepository.readMaximumBloodGlucoseDisplayed()),
                        moveToLatestValue: true)
                }
            }
            
            NightscoutDataRepository.singleton.storeHistoricBgData(BgDataHolder.singleton.getTodaysBgData())
        })
    }
    
    fileprivate func paintScreenLockSwitch() {
        screenlockSwitch.isOn = UIApplication.shared.isIdleTimerDisabled
    }
    
    fileprivate func paintCurrentBgData(_ nightscoutData : NightscoutData) {
        
        DispatchQueue.main.async(execute: {
            if nightscoutData.sgv == "---" {
                self.bgLabel.text = "---"
            } else {
                self.bgLabel.text = nightscoutData.sgv
            }
            self.bgLabel.textColor = UIColorChanger.getBgColor(nightscoutData.sgv)
            
            self.deltaLabel.text = nightscoutData.bgdeltaString.cleanFloatValue
            self.deltaArrowsLabel.text = nightscoutData.bgdeltaArrow
            self.deltaLabel.textColor = UIColorChanger.getDeltaLabelColor(NSNumber(value: nightscoutData.bgdelta))
            self.deltaArrowsLabel.textColor = UIColorChanger.getDeltaLabelColor(NSNumber(value: nightscoutData.bgdelta))
            
            self.lastUpdateLabel.text = nightscoutData.timeString
            self.lastUpdateLabel.textColor = UIColorChanger.getTimeLabelColor(nightscoutData.time)
            
            self.batteryLabel.text = nightscoutData.battery
        })
    }
    
    @IBAction func doSnoozeAction(_ sender: AnyObject) {
        
        if AlarmRule.isSnoozed() {
            AlarmRule.disableSnooze()
            snoozeButton.setTitle("Snooze", for: UIControlState())
        } else {
            // stop the alarm immediatly here not to disturb others
            AlarmSound.muteVolume()
            showSnoozePopup()
        }
    }
    
    fileprivate func showSnoozePopup() {
        let alert = UIAlertController(title: "Snooze",
            message: "How long should the alarm be ignored?",
            preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "30 Minutes",
            style: UIAlertActionStyle.default,
            handler: {(alert: UIAlertAction!) in
                
                self.snoozeMinutes(30)
        }))
        alert.addAction(UIAlertAction(title: "1 Hour",
            style: UIAlertActionStyle.default,
            handler: {(alert: UIAlertAction!) in
                
                self.snoozeMinutes(60)
        }))
        alert.addAction(UIAlertAction(title: "2 Hours",
            style: UIAlertActionStyle.default,
            handler: {(alert: UIAlertAction!) in
                
                self.snoozeMinutes(120)
        }))
        alert.addAction(UIAlertAction(title: "1 Day",
            style: UIAlertActionStyle.default,
            handler: {(alert: UIAlertAction!) in
                
                self.snoozeMinutes(24 * 60)
        }))
        alert.addAction(UIAlertAction(title: "Cancel",
            style: UIAlertActionStyle.default,
            handler: {(alert: UIAlertAction!) in
                
                AlarmSound.unmuteVolume()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func snoozeMinutes(_ minutes : Int) {
        
        AlarmRule.snooze(minutes)
        
        AlarmSound.stop()
        AlarmSound.unmuteVolume()
        self.updateSnoozeButtonText()
    }
    
    fileprivate func updateSnoozeButtonText() {
        
        if AlarmRule.isSnoozed() {
            snoozeButton.setTitle("Snoozed for " + String(AlarmRule.getRemainingSnoozeMinutes()) + "min", for: UIControlState())
        } else {
            snoozeButton.setTitle("Snooze", for: UIControlState())
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
            UserDefaults.standard.synchronize()
        }
    }
    
    fileprivate func paintCurrentTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        self.timeLabel.text = formatter.string(from: Date())
    }
}
