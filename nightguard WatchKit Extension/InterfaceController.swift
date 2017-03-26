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

    var chartScene : ChartScene? = nil
    
    var historicBgData : [BloodSugar] = []
    var currentNightscoutData : NightscoutData = NightscoutData()
    
    // timer to check continuously for new bgValues
    var timer = NSTimer()
    // check every 30 Seconds whether new bgvalues should be retrieved
    let timeInterval : NSTimeInterval = 30.0
    
    var zoomingIsActive : Bool = false
    var nrOfCrownRotations : Int = 0
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // load old values that have been stored before
        self.currentNightscoutData = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        self.historicBgData = NightscoutDataRepository.singleton.loadHistoricBgData()
        
        // update values immediately if necessary
        checkForNewValuesFromNightscoutServer()
        
        crownSequencer.focus()
        crownSequencer.delegate = self
        
        // Initialize the ChartScene
        let bounds = WKInterfaceDevice.currentDevice().screenBounds
        chartScene = ChartScene(size: CGSize(width: bounds.width, height: 130), newCanvasWidth: bounds.width * 6)
        spriteKitView.presentScene(chartScene)
        
        YesterdayBloodSugarService.singleton.getYesterdaysValuesTransformedToCurrentDay() { yesterdaysValues in
            
            let defaults = NSUserDefaults.standardUserDefaults()
            self.chartScene!.paintChart(
                [self.historicBgData, yesterdaysValues],
                newCanvasWidth: bounds.width * 6,
                maxYDisplayValue: CGFloat(defaults.floatForKey("maximumBloodGlucoseDisplayed")),
                moveToLatestValue: true)
        }
        
        createMenuItems()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        // Start the timer to retrieve new bgValues
        createNewTimerSingleton()
        timer.fire()
        
        checkForNewValuesFromNightscoutServer()
        paintCurrentBgData(currentNightscoutData)
    }
    
    override func didAppear() {
        assureThatBaseUriIsExisting()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func crownDidRotate(crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        
        if zoomingIsActive {
            nrOfCrownRotations += 1
            // only recognize every third rotation => Otherwise the watch will crash
            // because of too many calls a second
            if nrOfCrownRotations % 5 == 0 && abs(rotationalDelta) > 0.01 {
                chartScene!.scale(1 + CGFloat(rotationalDelta), keepScale: true)
            }
        } else {
            chartScene!.moveChart(rotationalDelta * 200)
        }
    }
    
    func doInfoMenuAction() {
        self.presentControllerWithName("InfoInterfaceController", context: nil)
    }
    
    func doRefreshMenuAction() {
        willActivate()
    }
    
    func doToogleZoomScrollAction() {
        zoomingIsActive = !zoomingIsActive
        createMenuItems()
    }
    
    func doCloseMenuAction() {
        // nothing to do - closes automatically
    }
    
    // check whether new Values should be retrieved
    func timerDidEnd(timer:NSTimer){
        assureThatBaseUriIsExisting()
        checkForNewValuesFromNightscoutServer()
    }
    
    // this has to be created programmatically, since only this way
    // the item Zoom/Scroll can be toggled
    private func createMenuItems() {
        self.clearAllMenuItems()
        self.addMenuItemWithItemIcon(WKMenuItemIcon.Info, title: "Info", action: #selector(InterfaceController.doInfoMenuAction))
        self.addMenuItemWithItemIcon(WKMenuItemIcon.Resume, title: "Refresh", action: #selector(InterfaceController.doRefreshMenuAction))
        self.addMenuItemWithItemIcon(WKMenuItemIcon.More, title: zoomingIsActive ? "Scroll" : "Zoom", action: #selector(InterfaceController.doToogleZoomScrollAction))
        self.addMenuItemWithItemIcon(WKMenuItemIcon.Decline, title: "Close", action: #selector(InterfaceController.doCloseMenuAction))
    }
    
    private func assureThatBaseUriIsExisting() {
        
        if UserDefaultsRepository.readBaseUri().isEmpty {
            AppMessageService.singleton.requestBaseUri()
        }
    }
    
    private func checkForNewValuesFromNightscoutServer() {
        
        if currentNightscoutData.isOlderThan5Minutes() {
            
            readNewValuesFromNightscoutServer()
        }
    }
    
    private func readNewValuesFromNightscoutServer() {
        
        let bounds = WKInterfaceDevice.currentDevice().screenBounds
        
        NightscoutService.singleton.readCurrentDataForPebbleWatch({(currentNightscoutData) -> Void in
            self.currentNightscoutData = currentNightscoutData
            self.paintCurrentBgData(self.currentNightscoutData)
            NightscoutDataRepository.singleton.storeCurrentNightscoutData(currentNightscoutData)
        })
        
        NightscoutService.singleton.readTodaysChartData({(historicBgData) -> Void in
            self.historicBgData = historicBgData
            YesterdayBloodSugarService.singleton.getYesterdaysValuesTransformedToCurrentDay() { yesterdaysValues in
                
                let (upperBound, _) = UserDefaultsRepository.readUpperLowerBounds()
                self.chartScene!.paintChart(
                    [historicBgData,yesterdaysValues],
                    newCanvasWidth: bounds.width * 6,
                    maxYDisplayValue: CGFloat(upperBound),
                    moveToLatestValue: true)
            }
            NightscoutDataRepository.singleton.storeHistoricBgData(self.historicBgData)
        })
    }
    
    private func createNewTimerSingleton() {
        if !timer.valid {
            timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval,
                                                       target: self,
                                                       selector: #selector(InterfaceController.timerDidEnd(_:)),
                                                       userInfo: nil,
                                                       repeats: true)
            // allow WatchOs to call this timer 30 seconds later as requested
            timer.tolerance = timeInterval
        }
    }
    
    private func paintCurrentBgData(currentNightscoutData : NightscoutData) {
        self.bgLabel.setText(currentNightscoutData.sgv)
        self.bgLabel.setTextColor(UIColorChanger.getBgColor(currentNightscoutData.sgv))
        
        self.deltaLabel.setText(currentNightscoutData.bgdeltaString.cleanFloatValue)
        self.deltaArrowLabel.setText(currentNightscoutData.bgdeltaArrow)
        self.deltaLabel.setTextColor(UIColorChanger.getDeltaLabelColor(currentNightscoutData.bgdelta))
        
        self.timeLabel.setText(currentNightscoutData.timeString)
        self.timeLabel.setTextColor(UIColorChanger.getTimeLabelColor(currentNightscoutData.time))
        
        self.batteryLabel.setText(currentNightscoutData.battery)
    }
}
