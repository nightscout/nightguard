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

class InterfaceController: WKInterfaceController, WCSessionDelegate {

    @IBOutlet var bgLabel: WKInterfaceLabel!
    @IBOutlet var deltaLabel: WKInterfaceLabel!
    @IBOutlet var timeLabel: WKInterfaceLabel!
    @IBOutlet var batteryLabel: WKInterfaceLabel!
    @IBOutlet var chartImage: WKInterfaceImage!
    
    @IBAction func doInfoMenuAction() {
    self.presentControllerWithName("InfoInterfaceController", context: nil)
    }
    
    @IBAction func doCloseMenuAction() {
        // nothing to do - closes automatically
    }
    
    var GREEN : UIColor = UIColor.init(red: 0.48, green: 0.9, blue: 0, alpha: 1)
    var YELLOW : UIColor = UIColor.init(red: 1, green: 0.94, blue: 0, alpha: 1)
    var RED : UIColor = UIColor.init(red: 1, green: 0.22, blue: 0.11, alpha: 1)
    
    var historicBgData : [Int] = []
    var currentBgData : BgData = BgData()
    
    // timer to check continuously for new bgValues
    var timer = NSTimer()
    // check every 30 Seconds whether new bgvalues should be retrieved
    let timeInterval:NSTimeInterval = 30.0
    
    
    // check whether new Values should be retrieved
    func timerDidEnd(timer:NSTimer){
        checkForNewValuesFromNightscoutServer()
    }
    
    func checkForNewValuesFromNightscoutServer() {
        
        if currentBgData.isOlderThan5Minutes() {
            
            readNewValuesFromNightscoutServer()
        }
    }
    
    func readNewValuesFromNightscoutServer() {
        ServiceBoundary.singleton.readCurrentDataForPebbleWatch({(bgData) -> Void in
            self.currentBgData = bgData
            self.paintCurrentBgData(self.currentBgData)
            DataRepository.singleton.storeCurrentBgData(bgData)
        })
        ServiceBoundary.singleton.readChartData({(historicBgData) -> Void in
            self.historicBgData = historicBgData
            self.paintChart(self.historicBgData)
            DataRepository.singleton.storeHistoricBgData(self.historicBgData)
        })
    }
    
    func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
        
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            
            if let hostUri = applicationContext["hostUri"] as? String {
                let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
                defaults!.setValue(hostUri, forKey: "hostUri")
            }
        }
    }
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // load old values that have been stored before
        self.currentBgData = DataRepository.singleton.loadCurrentBgData()
        self.historicBgData = DataRepository.singleton.loadHistoricBgData()
    
        // update values immediately if necessary
        checkForNewValuesFromNightscoutServer()
        
        // Start the timer to retrieve new bgValues
        timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval,
            target: self,
            selector: "timerDidEnd:",
            userInfo: nil,
            repeats: true)
    }

    override func willActivate() {
        if WCSession.isSupported() {
            let session = WCSession.defaultSession()
            session.delegate = self
            session.activateSession()
        }
        
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        paintChart(historicBgData)
        paintCurrentBgData(currentBgData)
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    private func paintChart(bgValues : [Int]) {
        let chartPainter : ChartPainter = ChartPainter();
        
        guard let chartImage = chartPainter.drawImage(bgValues) else {
            return
        }
        self.chartImage.setImage(chartImage)
    }
    
    private func paintCurrentBgData(bgData : BgData) {
        self.bgLabel.setText(bgData.sgv)
        self.colorBgLabel(self.bgLabel, bg: bgData.sgv)
        self.deltaLabel.setText(bgData.bgdeltaString)
        self.colorDeltaLabel(self.deltaLabel, bgdelta: bgData.bgdelta)
        self.timeLabel.setText(bgData.timeString)
        self.colorTimeLabel(self.timeLabel, lastUpdate: bgData.time)
        self.batteryLabel.setText(bgData.battery)
    }
    
    // Changes the color to red if blood glucose is bad :-/
    private func colorBgLabel(bgLabel : WKInterfaceLabel, bg : String) {
        guard let bgNumber : Int = Int(bg) else {
            bgLabel.setTextColor(UIColor.whiteColor())
            return;
        }
        if bgNumber > 200 {
            bgLabel.setTextColor(RED)
        } else if bgNumber > 180 {
            bgLabel.setTextColor(YELLOW)
        } else {
            bgLabel.setTextColor(UIColor.whiteColor())
        }
    }
    
    private func colorDeltaLabel(deltaLabel : WKInterfaceLabel, bgdelta : NSNumber) {
        let absoluteDelta = abs(bgdelta.intValue)
        if (absoluteDelta >= 10) {
            deltaLabel.setTextColor(RED)
        } else if (absoluteDelta >= 5) {
            deltaLabel.setTextColor(YELLOW)
        } else {
            deltaLabel.setTextColor(UIColor.whiteColor())
        }
    }
    
    private func colorTimeLabel(timeLabel : WKInterfaceLabel, lastUpdate : NSNumber) {
        let lastUpdateAsNSDate : NSDate = NSDate(timeIntervalSince1970: lastUpdate.doubleValue / 1000)
        let timeInterval : Int = Int(NSDate().timeIntervalSinceDate(lastUpdateAsNSDate))
        if (timeInterval > 7*60) {
            timeLabel.setTextColor(YELLOW)
        } else if (timeInterval > 15*60) {
            timeLabel.setTextColor(RED)
        } else {
            timeLabel.setTextColor(UIColor.whiteColor())
        }
    }
}