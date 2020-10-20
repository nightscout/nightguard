//
//  NightscoutViewModel.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 28.09.20.
//  Copyright © 2020 private. All rights reserved.
//

import Foundation
import SwiftUI
import SpriteKit
import ClockKit

@available(watchOSApplicationExtension 6.0, *)
class MainViewModel: ObservableObject, Identifiable {
    
    @Published var refreshingData = false
    
    @Published var nightscoutData: NightscoutData?
    
    @Published var sgvColor = Color.white
    @Published var sgvDeltaColor = Color.white
    @Published var arrowColor = Color.white
    @Published var timeColor = Color.white
    
    @Published var cannulaAge: String?
    @Published var batteryAge: String?
    @Published var sensorAge: String?
    
    @Published var reservoir: String = "?U"
    @Published var activeProfile: String = "---"
    @Published var temporaryBasal: String = "---"
    @Published var temporaryTarget: String = "---"
    
    @Published var error: Error?
    @Published var active: Bool = false
    
    @Published var skScene: ChartScene
    
    // Old values that have been read before
    @Published var cachedTodaysBgValues: [BloodSugar] = []
    @Published var cachedYesterdaysBgValues: [BloodSugar] = []

    @Published var alarmRuleMessage: String = ""
    
    init() {
        let bounds = WKInterfaceDevice.current().screenBounds
        let chartSceneHeight = MainViewModel.determineSceneHeightFromCurrentWatchType(interfaceBounds: bounds)
        
        skScene = ChartScene(size: CGSize(width: bounds.width, height: chartSceneHeight), newCanvasWidth: bounds.width * 6, useContrastfulColors: false)
        
        refreshData(forceRefresh: true, moveToLatestValue: true)
        
        alarmRuleMessage = determineInfoLabel()
    }
    
    func refreshData(forceRefresh : Bool, moveToLatestValue : Bool) {
        loadCurrentBgData(forceRefresh: forceRefresh)
        loadCareData()
        loadDeviceStatusData()
        loadChartData(forceRepaint: forceRefresh, moveToLatestValue: moveToLatestValue)
        
        alarmRuleMessage = determineInfoLabel()
        if AlarmRule.isAlarmActivated() {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    fileprivate func paintChartData(todaysData : [BloodSugar], yesterdaysData : [BloodSugar], moveToLatestValue : Bool) {
        
        let device = WKInterfaceDevice.current()
        let bounds = device.screenBounds
        
        let todaysDataWithPrediction = todaysData + PredictionService.singleton.nextHourGapped
        
        let chartSceneHeight = MainViewModel.determineSceneHeightFromCurrentWatchType(interfaceBounds: bounds)
        skScene = ChartScene(size: CGSize(width: bounds.width, height: chartSceneHeight), newCanvasWidth: bounds.width * 6, useContrastfulColors: false)
        skScene.paintChart(
            [todaysDataWithPrediction, yesterdaysData],
            newCanvasWidth: bounds.width * 6,
            maxYDisplayValue: CGFloat(UserDefaultsRepository.maximumBloodGlucoseDisplayed.value),
            moveToLatestValue: moveToLatestValue,
            displayDaysLegend: false,
            useConstrastfulColors: false)
    }
   
    func determineInfoLabel() -> String {
        
        if !AlarmRule.isSnoozed() {
            if let alarmReason = AlarmRule.getAlarmActivationReason() {
                return alarmReason
            } else {
                return ""
            }
        }
        
        return String(format: NSLocalizedString("Snoozed %dmin", comment: "Snoozed duration on watch"), AlarmRule.getRemainingSnoozeMinutes())
    }
    
    fileprivate static func determineSceneHeightFromCurrentWatchType(interfaceBounds : CGRect) -> CGFloat {
        
        if (interfaceBounds.height >= 224.0) {
            // Apple Watch 44mm
            return 165.0
        }
        if (interfaceBounds.height >= 195.0) {
            // Apple Watch 42mm
            return 145.0
        }
        
        // interfaceBounds.height == 170.0
        // Apple Watch 38mm
        return 125.0
    }
    
    func loadCurrentBgData(forceRefresh: Bool) {

        // do not call refresh again if not needed
        guard forceRefresh || !NightscoutCacheService.singleton.hasCurrentNightscoutDataPendingRequests else {
            return
        }

        self.refreshingData = true
        
        self.nightscoutData = NightscoutCacheService.singleton.loadCurrentNightscoutData(forceRefresh: forceRefresh) { [unowned self] result in
            
            guard let result = result else { return }
            
             dispatchOnMain { [unowned self] in
                
                self.refreshingData = false
                guard self.active else { return }
                
                switch result {
                case .data(let newNightscoutData):
                    calculateColors(nightscoutData: newNightscoutData)
                    self.nightscoutData = newNightscoutData
                    self.active = false
                    updateComplication()
                case .error(let error):
                    self.error = error
                    self.active = false
                }
            }
        }
        
        if NightscoutCacheService.singleton.hasCurrentNightscoutDataPendingRequests {
            
            self.active = true
        }
    }
    
    fileprivate func updateComplication() {
        let complicationServer = CLKComplicationServer.sharedInstance()
        for complication in complicationServer.activeComplications! {
            complicationServer.reloadTimeline(for: complication)
        }
    }
    
    fileprivate func calculateColors(nightscoutData: NightscoutData) {
        
        self.sgvColor = Color(UIColorChanger.getBgColor(UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)))
        self.sgvDeltaColor = Color(UIColorChanger.getDeltaLabelColor(
                UnitsConverter.mgdlToDisplayUnits(nightscoutData.bgdelta)))
        self.arrowColor = Color(
                UIColorChanger.getDeltaLabelColor(
                    UnitsConverter.mgdlToDisplayUnits(nightscoutData.bgdelta)))
        self.timeColor = Color(UIColorChanger.getTimeLabelColor(nightscoutData.time))
    }
    
    fileprivate func loadCareData() {
        
        self.sensorAge = NightscoutCacheService.singleton.getSensorChangeTime().convertToAge(prefix: "S ")
        self.cannulaAge = NightscoutCacheService.singleton.getCannulaChangeTime().convertToAge(prefix: "C ")
        self.batteryAge = NightscoutCacheService.singleton.getPumpBatteryChangeTime().convertToAge(prefix: "B ")
    }
    
    fileprivate func loadDeviceStatusData() {

        let deviceStatusData = NightscoutCacheService.singleton.getDeviceStatusData({ [unowned self] result in
            self.extractDeviceStatusData(deviceStatusData: result)
        })
        
        self.extractDeviceStatusData(deviceStatusData: deviceStatusData)
    }
    
    fileprivate func extractDeviceStatusData(deviceStatusData: DeviceStatusData) {
        
        self.reservoir = "R \(String(describing: deviceStatusData.reservoirUnits))"
        self.activeProfile =
            deviceStatusData.activePumpProfile.trimInfix(keepPrefixCharacterCount: 4, keepPostfixCharacterCount: 6)
        if deviceStatusData.temporaryBasalRate != "" &&
            deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes() > 0 {
            
            self.temporaryBasal = "TB \(deviceStatusData.temporaryBasalRate)% \(deviceStatusData.temporaryBasalRateActiveUntil.remainingMinutes())m"
        } else {
            self.temporaryBasal = "TB --"
        }
        
        let temporaryTargetData = NightscoutCacheService.singleton.getTemporaryTargetData()
        if temporaryTargetData.activeUntilDate.remainingMinutes() > 0 {
            self.temporaryTarget = "TT \(UnitsConverter.mgdlToDisplayUnits(String(describing: temporaryTargetData.targetTop))) \(temporaryTargetData.activeUntilDate.remainingMinutes())m"
        } else {
            self.temporaryTarget = "TT --"
        }
    }
    
    func loadChartData(forceRepaint : Bool, moveToLatestValue : Bool) {
        
        // show a message if the today & yesterday data is missing, we're gonna load them now (will show on first install and when URI changes)
        if UserDefaultsRepository.baseUri.exists && NightscoutCacheService.singleton.isEmpty && NightscoutDataRepository.singleton.isEmpty {
            //TODO
            //showMessage("Loading BG data...")
        }
        
        let newCachedTodaysBgValues: [BloodSugar]
        if NightscoutCacheService.singleton.hasTodaysBgDataPendingRequests {
           newCachedTodaysBgValues = NightscoutDataRepository.singleton.loadTodaysBgData()
        } else {
            newCachedTodaysBgValues = NightscoutCacheService.singleton.loadTodaysData { [unowned self] result in
                guard let result = result else { return }

                dispatchOnMain { [unowned self] in
                    guard active else { return }
                    
                    if case .data(let newTodaysData) = result {
                        self.cachedTodaysBgValues = newTodaysData
                        paintChartData(todaysData : cachedTodaysBgValues, yesterdaysData : cachedYesterdaysBgValues, moveToLatestValue : true)
                    }
                }
            }
        }
        cachedTodaysBgValues = newCachedTodaysBgValues
        
        let newCachedYesterdaysBgValues: [BloodSugar]
        if NightscoutCacheService.singleton.hasYesterdaysBgDataPendingRequests {
            newCachedYesterdaysBgValues = NightscoutDataRepository.singleton.loadYesterdaysBgData()
        } else {
            newCachedYesterdaysBgValues = NightscoutCacheService.singleton.loadYesterdaysData { [unowned self] result in
                guard let result = result else { return }

                dispatchOnMain { [unowned self] in
                    guard active else { return }
                    
                    if case .data(let newYesterdaysData) = result {
                        self.cachedYesterdaysBgValues = newYesterdaysData
                        paintChartData(todaysData : cachedTodaysBgValues, yesterdaysData : cachedYesterdaysBgValues, moveToLatestValue : true)
                    }
                }
            }
        }
        
        cachedYesterdaysBgValues = newCachedYesterdaysBgValues
        if forceRepaint {
            paintChartData(todaysData : cachedTodaysBgValues, yesterdaysData : cachedYesterdaysBgValues, moveToLatestValue : moveToLatestValue)
        }
    }
}
