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
    
    private func checkForNewValuesFromNightscoutServer() {
        
        if currentBgData.isOlderThan5Minutes() {
            
            readNewValuesFromNightscoutServer()
        }
    }
    
    private func readNewValuesFromNightscoutServer() {
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
        
        let chartPainter : ChartPainter = ChartPainter(canvasWidth: 165, canvasHeight: 125);
        
        guard let chartImage = chartPainter.drawImage(bgValues) else {
            return
        }
        self.chartImage.setImage(chartImage)
    }
    
    private func paintCurrentBgData(bgData : BgData) {
        self.bgLabel.setText(bgData.sgv)
        self.bgLabel.setTextColor(UIColorChanger.getBgColor(bgData.sgv))
        
        self.deltaLabel.setText(bgData.bgdeltaString)
        self.deltaLabel.setTextColor(UIColorChanger.getDeltaLabelColor(bgData.bgdelta))
        
        self.timeLabel.setText(bgData.timeString)
        self.timeLabel.setTextColor(UIColorChanger.getTimeLabelColor(bgData.time))
        
        self.batteryLabel.setText(bgData.battery)
    }
}