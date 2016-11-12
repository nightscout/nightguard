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

class MainViewController: UIViewController {
    
    @IBOutlet weak var bgLabel: UILabel!
    @IBOutlet weak var deltaLabel: UILabel!
    @IBOutlet weak var deltaArrowsLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var lastUpdateLabel: UILabel!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var chartImage: UIImageView!
    @IBOutlet weak var snoozeButton: UIButton!
    @IBOutlet weak var screenlockSwitch: UISwitch!
    @IBOutlet weak var volumeContainerView: UIView!

    
    // timer to check continuously for new bgValues
    var timer = NSTimer()
    // check every 5 Seconds whether new bgvalues should be retrieved
    let timeInterval:NSTimeInterval = 5.0
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Portrait
    }
    
    override func viewDidAppear(animated: Bool) {
        
        let value = UIInterfaceOrientation.Portrait.rawValue
        UIDevice.currentDevice().setValue(value, forKey: "orientation")
        
        let historicBgData = BgDataHolder.singleton.getHistoricBgData()
        paintChart(historicBgData,
                   yesterdayValues: YesterdayBloodSugarService.singleton.getYesterdaysValuesTransformedToCurrentDay(
                    BloodSugar.getMinimumTimestamp(historicBgData),
                    to: BloodSugar.getMaximumTimestamp(historicBgData)))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Embed the Volume Slider View
        // This way the system volume can be
        // controlled by the user
        let volumeView = MPVolumeView(frame: volumeContainerView.bounds)
        volumeView.backgroundColor = UIColor.blackColor()
        volumeView.tintColor = UIColor.grayColor()
        volumeContainerView.addSubview(volumeView)
        // add an observer to resize the MPVolumeView when displayed on e.g. 4.7" iPhone
        volumeContainerView.addObserver(self, forKeyPath: "bounds", options: [], context: nil)
        
        // snooze the alarm for 15 Seconds in order to retrieve new data
        // before playing alarm
        AlarmRule.snoozeSeconds(15)
        
        checkForNewValuesFromNightscoutServer()
        restoreGuiState()
        
        paintScreenLockSwitch()
        paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
        let historicBgData = BgDataHolder.singleton.getHistoricBgData()
        paintChart(historicBgData,
                   yesterdayValues: YesterdayBloodSugarService.singleton.getYesterdaysValuesTransformedToCurrentDay(
                        BloodSugar.getMinimumTimestamp(historicBgData),
                        to: BloodSugar.getMaximumTimestamp(historicBgData)))
        
        // Start the timer to retrieve new bgValues
        timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval,
            target: self,
            selector: #selector(MainViewController.timerDidEnd(_:)),
            userInfo: nil,
            repeats: true)
        // Start immediately so that the current time gets display at once
        // And the alarm can play if needed
        timerDidEnd(timer)
    }
    
    // Resize the MPVolumeView when the parent view changes
    // This is needed on an e.g. 4,7" iPhone. Otherwise the MPVolumeView would be too small
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

        let volumeView = MPVolumeView(frame: volumeContainerView.bounds)
        volumeView.backgroundColor = UIColor.blackColor()
        volumeView.tintColor = UIColor.grayColor()

        for view in volumeContainerView.subviews {
            view.removeFromSuperview()
        }
        volumeContainerView.addSubview(volumeView)
    }
    
    private func restoreGuiState() {
        
        screenlockSwitch.on = GuiStateRepository.singleton.loadScreenlockSwitchState()
        doScreenlockAction(self)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    private func paintChart(bgValues : [BloodSugar], yesterdayValues : [BloodSugar]) {
        
        let chartPainter : ChartPainter = ChartPainter(
            canvasWidth: Int(chartImage.frame.size.width),
            canvasHeight: Int(chartImage.frame.size.height));
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        guard let chartImage = chartPainter.drawImage(
                [UnitsConverter.toDisplayUnits(bgValues), UnitsConverter.toDisplayUnits(yesterdayValues)],
                upperBoundNiceValue: UnitsConverter.toDisplayUnits(defaults!.floatForKey("alertIfAboveValue")),
                lowerBoundNiceValue: UnitsConverter.toDisplayUnits(defaults!.floatForKey("alertIfBelowValue"))
        ) else {
            return
        }
        dispatch_async(dispatch_get_main_queue(), {
            self.chartImage.image = chartImage
        })
    }
    
    // check whether new Values should be retrieved
    func timerDidEnd(timer:NSTimer) {
        
        checkForNewValuesFromNightscoutServer()
        if AlarmRule.isAlarmActivated(BgDataHolder.singleton.getCurrentBgData(), bloodValues: BgDataHolder.singleton.getHistoricBgData()) {
            AlarmSound.play()
        } else {
            AlarmSound.stop()
        }
        updateSnoozeButtonText()
        
        paintCurrentTime()
        // paint here is need if the server doesn't respond
        // => in that case the user has to know that the values are old!
        paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
    }
    
    private func checkForNewValuesFromNightscoutServer() {
        
        YesterdayBloodSugarService.singleton.warmupCache()
        if BgDataHolder.singleton.getCurrentBgData().isOlderThan5Minutes() {
            
            readNewValuesFromNightscoutServer()
        } else {
            paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
        }
    }
    
    private func readNewValuesFromNightscoutServer() {
        
        NightscoutService.singleton.readCurrentDataForPebbleWatch({(nightscoutData) -> Void in
            BgDataHolder.singleton.setCurrentBgData(nightscoutData)
            self.paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
            NightscoutDataRepository.singleton.storeCurrentNightscoutData(nightscoutData)
        })
        NightscoutService.singleton.readLastTwoHoursChartData({(historicBgData) -> Void in
            BgDataHolder.singleton.setHistoricBgData(historicBgData)
            self.paintChart(historicBgData, yesterdayValues:
                YesterdayBloodSugarService.singleton.getYesterdaysValuesTransformedToCurrentDay(
                    BloodSugar.getMinimumTimestamp(historicBgData),
                    to: BloodSugar.getMaximumTimestamp(historicBgData)))
            
            NightscoutDataRepository.singleton.storeHistoricBgData(BgDataHolder.singleton.getHistoricBgData())
        })
    }
    
    private func paintScreenLockSwitch() {
        screenlockSwitch.on = UIApplication.sharedApplication().idleTimerDisabled
    }
    
    private func paintCurrentBgData(nightscoutData : NightscoutData) {
        
        dispatch_async(dispatch_get_main_queue(), {
            if nightscoutData.sgv == "---" {
                self.bgLabel.text = "---"
            } else {
                self.bgLabel.text = nightscoutData.sgv
            }
            self.bgLabel.textColor = UIColorChanger.getBgColor(nightscoutData.sgv)
            
            self.deltaLabel.text = nightscoutData.bgdeltaString.cleanFloatValue
            self.deltaArrowsLabel.text = nightscoutData.bgdeltaArrow
            self.deltaLabel.textColor = UIColorChanger.getDeltaLabelColor(nightscoutData.bgdelta)
            self.deltaArrowsLabel.textColor = UIColorChanger.getDeltaLabelColor(nightscoutData.bgdelta)
            
            self.lastUpdateLabel.text = nightscoutData.timeString
            self.lastUpdateLabel.textColor = UIColorChanger.getTimeLabelColor(nightscoutData.time)
            
            self.batteryLabel.text = nightscoutData.battery
        })
    }
    
    @IBAction func doSnoozeAction(sender: AnyObject) {
        
        if AlarmRule.isSnoozed() {
            AlarmRule.disableSnooze()
            snoozeButton.setTitle("Snooze", forState: UIControlState.Normal)
        } else {
            // stop the alarm immediatly here not to disturb others
            AlarmSound.muteVolume()
            showSnoozePopup()
        }
    }
    
    private func showSnoozePopup() {
        let alert = UIAlertController(title: "Snooze",
            message: "How long should the alarm be ignored?",
            preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "30 Minutes",
            style: UIAlertActionStyle.Default,
            handler: {(alert: UIAlertAction!) in
                
                self.snoozeMinutes(30)
        }))
        alert.addAction(UIAlertAction(title: "1 Hour",
            style: UIAlertActionStyle.Default,
            handler: {(alert: UIAlertAction!) in
                
                self.snoozeMinutes(60)
        }))
        alert.addAction(UIAlertAction(title: "2 Hours",
            style: UIAlertActionStyle.Default,
            handler: {(alert: UIAlertAction!) in
                
                self.snoozeMinutes(120)
        }))
        alert.addAction(UIAlertAction(title: "1 Day",
            style: UIAlertActionStyle.Default,
            handler: {(alert: UIAlertAction!) in
                
                self.snoozeMinutes(24 * 60)
        }))
        alert.addAction(UIAlertAction(title: "Cancel",
            style: UIAlertActionStyle.Default,
            handler: {(alert: UIAlertAction!) in
                
                AlarmSound.unmuteVolume()
        }))
        presentViewController(alert, animated: true, completion: nil)
    }
    
    private func snoozeMinutes(minutes : Int) {
        
        AlarmRule.snooze(minutes)
        
        AlarmSound.stop()
        AlarmSound.unmuteVolume()
        self.updateSnoozeButtonText()
    }
    
    private func updateSnoozeButtonText() {
        
        if AlarmRule.isSnoozed() {
            snoozeButton.setTitle("Snoozed for " + String(AlarmRule.getRemainingSnoozeMinutes()) + "min", forState: UIControlState.Normal)
        } else {
            snoozeButton.setTitle("Snooze", forState: UIControlState.Normal)
        }
    }
    
    @IBAction func doScreenlockAction(sender: AnyObject) {
        if screenlockSwitch.on {
            UIApplication.sharedApplication().idleTimerDisabled = true
            GuiStateRepository.singleton.storeScreenlockSwitchState(true)
            
            displayScreenlockInfoMessageOnlyOnce()
        } else {
            UIApplication.sharedApplication().idleTimerDisabled = false
            GuiStateRepository.singleton.storeScreenlockSwitchState(false)
        }
    }
    
    private func displayScreenlockInfoMessageOnlyOnce() {
        let screenlockMessageShowed = NSUserDefaults.standardUserDefaults().boolForKey("screenlockMessageShowed")
        
        if !screenlockMessageShowed {
            
            let alertController = UIAlertController(title: "Keep the screen active", message: "Turn this switch to disable the screenlock and prevent the app to get stopped!", preferredStyle: .Alert)
            let actionOk = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alertController.addAction(actionOk)
            presentViewController(alertController, animated: true, completion: nil)
            
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: "screenlockMessageShowed")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    private func paintCurrentTime() {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "HH:mm"
        self.timeLabel.text = formatter.stringFromDate(NSDate())
    }
}
