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
    @IBOutlet var iobLabel: WKInterfaceLabel!
    
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
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Initialize the ChartScene
        let bounds = WKInterfaceDevice.current().screenBounds
        let chartSceneHeight = determineSceneHeightFromCurrentWatchType(interfaceBounds: bounds)
        chartScene = ChartScene(size: CGSize(width: bounds.width, height: chartSceneHeight), newCanvasWidth: bounds.width * 6)
        spriteKitView.presentScene(chartScene)
        
        createMenuItems()
    }
    
    fileprivate func determineSceneHeightFromCurrentWatchType(interfaceBounds : CGRect) -> CGFloat {
        
        if (interfaceBounds.height == 195.0) {
            // Apple Watch 42mm
            return 145.0
        }
        
        // interfaceBounds.height == 170.0
        // Apple Watch 38mm
        return 125.0
    }
    
    override func willActivate() {
        
        spriteKitView.isPaused = false
        
        // Start the timer to retrieve new bgValues and update the ui periodically
        // if the user keeps the display active for a longer time
        createNewTimerSingleton()
        
        // manually refresh the gui by fireing the timer
        timerDidEnd(timer)
        
        // Ask to get 8 minutes of cpu runtime to get the next values if
        // the app stays in frontmost state
        if #available(watchOSApplicationExtension 4.0, *) {
            WKExtension.shared().isFrontmostTimeoutExtended = true
        }
        
        crownSequencer.focus()
        crownSequencer.delegate = self
    }
    
    override func didAppear() {
        
        spriteKitView.isPaused = false
        
        crownSequencer.focus()
        crownSequencer.delegate = self
    }
    
    override func willDisappear() {
        spriteKitView.isPaused = true
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        
        timer.invalidate();
        spriteKitView.isPaused = true
    }
    
    // called when the crown rotates, rotationalDelta is the change since the last call (sign indicates direction).
    func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        
        if zoomingIsActive {
            nrOfCrownRotations += 1
            // only recognize every third rotation => Otherwise the watch will crash
            // because of too many calls a second
            if nrOfCrownRotations % 5 == 0 && abs(rotationalDelta) > 0.01 {
                chartScene.scale(1 + CGFloat(rotationalDelta), keepScale: true)
            }
        } else {
            chartScene.moveChart(rotationalDelta * 200)
        }
    }
    
    @objc func doInfoMenuAction() {
        self.presentController(withName: "InfoInterfaceController", context: nil)
    }
    
    @objc func doRefreshMenuAction() {
        NightscoutCacheService.singleton.resetCache()
        
        loadAndPaintCurrentBgData()
        loadAndPaintChartData(forceRepaint: true)
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
    
    // check whether new Values should be retrieved
    @objc func timerDidEnd(_ timer:Timer){
        assureThatBaseUriIsExisting()
        assureThatDisplayUnitsIsDefined()
        
        loadAndPaintCurrentBgData()
        loadAndPaintChartData(forceRepaint: false)
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
    
    fileprivate func assureThatDisplayUnitsIsDefined() {
        
        if !UserDefaultsRepository.areUnitsDefined() {
            // try to determine whether the user wishes to see value in mmol or mg/dL
            NightscoutService.singleton.readStatus { (units) in
                UserDefaultsRepository.saveUnits(units)
            }
        }
    }
    
    // Returns true, if the size of one array changed
    fileprivate func valuesChanged(newCachedTodaysBgValues : [BloodSugar], newCachedYesterdaysBgValues : [BloodSugar]) -> Bool {
        
        return newCachedTodaysBgValues.count != cachedTodaysBgValues.count ||
                newCachedYesterdaysBgValues.count != cachedYesterdaysBgValues.count
    }
    
    fileprivate func loadAndPaintCurrentBgData() {
        
        let currentNightscoutData = NightscoutCacheService.singleton.loadCurrentNightscoutData({(newNightscoutData) -> Void in
            
            DispatchQueue.main.async {
                self.paintCurrentBgData(currentNightscoutData: newNightscoutData)
                self.updateComplication()
                self.playAlarm(currentNightscoutData: newNightscoutData)
            }
        })
        
        paintCurrentBgData(currentNightscoutData: currentNightscoutData)
    }
    
    fileprivate func playAlarm(currentNightscoutData : NightscoutData) {
        
        guard let soundToPlay = determineSoundToPlay(currentNightscoutData: currentNightscoutData) else {
            return
        }
        WKInterfaceDevice.current().play(soundToPlay)
    }
    
    fileprivate func determineSoundToPlay(currentNightscoutData : NightscoutData) -> WKHapticType? {
        
        let (upperBound, lowerBound) = UserDefaultsRepository.readUpperLowerBounds()
        if currentNightscoutData.sgv == "---" {
            return nil
        }
        guard let sgvFloat = Float(currentNightscoutData.sgv) else {
            return nil
        }
        if sgvFloat > upperBound {
            return .directionUp
        }
        if sgvFloat < lowerBound {
            return .directionDown
        }
        return nil
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
        self.iobLabel.setText(currentNightscoutData.iob)
    }
    
    fileprivate func loadAndPaintChartData(forceRepaint : Bool) {
        
        let newCachedTodaysBgValues = NightscoutCacheService.singleton.loadTodaysData({(newTodaysData) -> Void in
            
            DispatchQueue.main.async {
                self.cachedTodaysBgValues = newTodaysData
                self.paintChartData(todaysData: newTodaysData, yesterdaysData: self.cachedYesterdaysBgValues, moveToLatestValue: true)
            }
        })
        let newCachedYesterdaysBgValues = NightscoutCacheService.singleton.loadYesterdaysData({(newYesterdaysData) -> Void in
            
            DispatchQueue.main.async {
                self.cachedYesterdaysBgValues = newYesterdaysData
                self.paintChartData(todaysData: self.cachedTodaysBgValues, yesterdaysData: newYesterdaysData, moveToLatestValue: false)
            }
        })
        
        // this does a fast paint of eventually cached data
        if forceRepaint ||
            valuesChanged(newCachedTodaysBgValues: newCachedTodaysBgValues, newCachedYesterdaysBgValues: newCachedYesterdaysBgValues) {
            
            cachedTodaysBgValues = newCachedTodaysBgValues
            cachedYesterdaysBgValues = newCachedYesterdaysBgValues
            paintChartData(todaysData: cachedTodaysBgValues, yesterdaysData: cachedYesterdaysBgValues, moveToLatestValue: false)
        }
    }
    
    fileprivate func paintChartData(todaysData : [BloodSugar], yesterdaysData : [BloodSugar], moveToLatestValue : Bool) {
        
        let bounds = WKInterfaceDevice.current().screenBounds
        self.chartScene.paintChart(
            [todaysData, yesterdaysData],
            newCanvasWidth: bounds.width * 6,
            maxYDisplayValue: CGFloat(UserDefaultsRepository.readMaximumBloodGlucoseDisplayed()),
            moveToLatestValue: moveToLatestValue,
            displayDaysLegend: false)
    }

}
