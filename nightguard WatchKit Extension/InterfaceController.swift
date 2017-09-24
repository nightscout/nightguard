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
    var timer = Timer()
    // check every 30 Seconds whether new bgvalues should be retrieved
    let timeInterval : TimeInterval = 30.0
    
    var zoomingIsActive : Bool = false
    var nrOfCrownRotations : Int = 0
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // load old values that have been stored before
        self.currentNightscoutData = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        self.historicBgData = NightscoutDataRepository.singleton.loadHistoricBgData()
        
        // update values immediately if necessary
        checkForNewValuesFromNightscoutServer()
        
        // Initialize the ChartScene
        let bounds = WKInterfaceDevice.current().screenBounds
        chartScene = ChartScene(size: CGSize(width: bounds.width, height: 130), newCanvasWidth: bounds.width * 6)
        spriteKitView.presentScene(chartScene)
        
        YesterdayBloodSugarService.singleton.getYesterdaysValuesTransformedToCurrentDay() { yesterdaysValues in
            
            self.chartScene!.paintChart(
                [self.historicBgData, yesterdaysValues],
                newCanvasWidth: bounds.width * 6,
                maxYDisplayValue: CGFloat(UserDefaultsRepository.readMaximumBloodGlucoseDisplayed()),
                moveToLatestValue: true)
        }
        
        createMenuItems()
    }
    
w
    
    override func didAppear() {
        assureThatBaseUriIsExisting()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // called when the crown rotates, rotationalDelta is the change since the last call (sign indicates direction).
    func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        
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
    
    @objc func doInfoMenuAction() {
        self.presentController(withName: "InfoInterfaceController", context: nil)
    }
    
    @objc func doRefreshMenuAction() {
        willActivate()
    }
    
    @objc func doToogleZoomScrollAction() {
        zoomingIsActive = !zoomingIsActive
        createMenuItems()
    }
    
    @objc func doCloseMenuAction() {
        // nothing to do - closes automatically
    }
    
    // check whether new Values should be retrieved
    @objc func timerDidEnd(_ timer:Timer){
        assureThatBaseUriIsExisting()
        checkForNewValuesFromNightscoutServer()
    }
    
    // this has to be created programmatically, since only this way
    // the item Zoom/Scroll can be toggled
    fileprivate func createMenuItems() {
        self.clearAllMenuItems()
        self.addMenuItem(with: WKMenuItemIcon.info, title: "Info", action: #selector(InterfaceController.doInfoMenuAction))
        self.addMenuItem(with: WKMenuItemIcon.resume, title: "Refresh", action: #selector(InterfaceController.doRefreshMenuAction))
        self.addMenuItem(with: WKMenuItemIcon.more, title: zoomingIsActive ? "Scroll" : "Zoom", action: #selector(InterfaceController.doToogleZoomScrollAction))
        self.addMenuItem(with: WKMenuItemIcon.decline, title: "Close", action: #selector(InterfaceController.doCloseMenuAction))
    }
    
    fileprivate func assureThatBaseUriIsExisting() {
        
        if UserDefaultsRepository.readBaseUri().isEmpty {
            AppMessageService.singleton.requestBaseUri()
        }
    }
    
    fileprivate func checkForNewValuesFromNightscoutServer() {
        
        if !UserDefaultsRepository.areUnitsDefined() {
            // try to determine whether the user wishes to see value in mmol or mg/dL
            NightscoutService.singleton.readStatus { (units) in
                UserDefaultsRepository.saveUnits(units)
            }
        }
        
        if currentNightscoutData.isOlderThan5Minutes() {
            
            readNewValuesFromNightscoutServer()
        }
    }
    
    fileprivate func readNewValuesFromNightscoutServer() {
        
        let bounds = WKInterfaceDevice.current().screenBounds
        
        NightscoutService.singleton.readCurrentDataForPebbleWatch({(currentNightscoutData) -> Void in
            self.currentNightscoutData = currentNightscoutData
            self.paintCurrentBgData(self.currentNightscoutData)
            NightscoutDataRepository.singleton.storeCurrentNightscoutData(currentNightscoutData)
        })
        
        NightscoutService.singleton.readTodaysChartData({(historicBgData) -> Void in
            self.historicBgData = historicBgData
            YesterdayBloodSugarService.singleton.getYesterdaysValuesTransformedToCurrentDay() { yesterdaysValues in
                
                self.chartScene!.paintChart(
                    [historicBgData,yesterdaysValues],
                    newCanvasWidth: bounds.width * 6,
                    maxYDisplayValue: CGFloat(UserDefaultsRepository.readMaximumBloodGlucoseDisplayed()),
                    moveToLatestValue: true)
            }
            NightscoutDataRepository.singleton.storeHistoricBgData(self.historicBgData)
        })
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
    
    fileprivate func paintCurrentBgData(_ currentNightscoutData : NightscoutData) {
        self.bgLabel.setText(currentNightscoutData.sgv)
        self.bgLabel.setTextColor(UIColorChanger.getBgColor(currentNightscoutData.sgv))
        
        self.deltaLabel.setText(currentNightscoutData.bgdeltaString.cleanFloatValue)
        self.deltaArrowLabel.setText(currentNightscoutData.bgdeltaArrow)
        self.deltaLabel.setTextColor(UIColorChanger.getDeltaLabelColor(NSNumber(value : currentNightscoutData.bgdelta)))
        
        self.timeLabel.setText(currentNightscoutData.timeString)
        self.timeLabel.setTextColor(UIColorChanger.getTimeLabelColor(currentNightscoutData.time))
        
        self.batteryLabel.setText(currentNightscoutData.battery)
    }
}
