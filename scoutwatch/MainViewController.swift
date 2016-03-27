//
//  MainViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 02.01.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    
    @IBOutlet weak var bgLabel: UILabel!
    @IBOutlet weak var deltaLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var lastUpdateLabel: UILabel!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var chartImage: UIImageView!
    @IBOutlet weak var snoozeButton: UIButton!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var screenlockSwitch: UISwitch!
    
    // timer to check continuously for new bgValues
    var timer = NSTimer()
    // check every 10 Seconds whether new bgvalues should be retrieved
    let timeInterval:NSTimeInterval = 5.0
    
    override func viewDidLoad() {        
        super.viewDidLoad()
        
        // snooze the alarm for 5 Seconds in order to retrieve new data
        // before playing alarm
        AlarmRule.snoozeSeconds(5)
        
        checkForNewValuesFromNightscoutServer()
        restoreGuiState()
        
        paintVolumeSlider()
        paintScreenLockSwitch()
        paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
        paintChart(BgDataHolder.singleton.getHistoricBgData())
        
        // Start the timer to retrieve new bgValues
        timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval,
            target: self,
            selector: "timerDidEnd:",
            userInfo: nil,
            repeats: true)
        // Start immediately so that the current time gets display at once
        // And the alarm can play if needed
        timerDidEnd(timer)
    }
    
    private func restoreGuiState() {
        volumeSlider.value = GuiStateRepository.singleton.loadVolumeSliderPosition()
        doChangeVolumeAction(self)
        
        screenlockSwitch.on = GuiStateRepository.singleton.loadScreenlockSwitchState()
        doScreenlockAction(self)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    private func paintChart(bgValues : [Int]) {
        
        let chartPainter : ChartPainter = ChartPainter(
            canvasWidth: Int(chartImage.frame.size.width),
            canvasHeight: Int(chartImage.frame.size.height));
        
        guard let chartImage = chartPainter.drawImage(bgValues) else {
            return
        }
        dispatch_async(dispatch_get_main_queue(), {
            self.chartImage.image = chartImage
        })
    }
    
    // check whether new Values should be retrieved
    func timerDidEnd(timer:NSTimer) {
        
        checkForNewValuesFromNightscoutServer()
        if AlarmRule.isAlarmActivated(BgDataHolder.singleton.getCurrentBgData()) {
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
        
        if BgDataHolder.singleton.getCurrentBgData().isOlderThan5Minutes() {
            
            readNewValuesFromNightscoutServer()
        } else {
            paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
        }
    }
    
    private func readNewValuesFromNightscoutServer() {
        
        ServiceBoundary.singleton.readCurrentDataForPebbleWatch({(bgData) -> Void in
            BgDataHolder.singleton.setCurrentBgData(bgData)
            self.paintCurrentBgData(BgDataHolder.singleton.getCurrentBgData())
            DataRepository.singleton.storeCurrentBgData(bgData)
        })
        ServiceBoundary.singleton.readChartData({(historicBgData) -> Void in
            BgDataHolder.singleton.setHistoricBgData(historicBgData)
            self.paintChart(BgDataHolder.singleton.getHistoricBgData())
            DataRepository.singleton.storeHistoricBgData(BgDataHolder.singleton.getHistoricBgData())
        })
    }
    
    private func paintVolumeSlider() {
        volumeSlider.value = AlarmSound.getAlarmVolume()
    }
    
    private func paintScreenLockSwitch() {
        screenlockSwitch.on = UIApplication.sharedApplication().idleTimerDisabled
    }
    
    private func paintCurrentBgData(bgData : BgData) {
        
        dispatch_async(dispatch_get_main_queue(), {
            self.bgLabel.text = bgData.sgv
            self.bgLabel.textColor = UIColorChanger.getBgColor(bgData.sgv)
            
            self.deltaLabel.text = bgData.bgdeltaString
            self.deltaLabel.textColor = UIColorChanger.getDeltaLabelColor(bgData.bgdelta)
            
            self.lastUpdateLabel.text = bgData.timeString
            self.lastUpdateLabel.textColor = UIColorChanger.getTimeLabelColor(bgData.time)
            
            self.batteryLabel.text = bgData.battery
        })
    }
    
    @IBAction func doChangeVolumeAction(sender: AnyObject) {
        
        AlarmSound.changeAlarmVolume(volumeSlider.value)
        GuiStateRepository.singleton.storeVolumeSliderPosition(volumeSlider.value)
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