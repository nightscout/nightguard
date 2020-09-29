//
//  NightscoutViewModel.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 28.09.20.
//  Copyright © 2020 private. All rights reserved.
//

import Foundation
import SwiftUI

class MainViewModel: ObservableObject, Identifiable {
    
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
    
    init() {
        loadCurrentBgData(forceRefresh: false)
        loadCareData()
        loadDeviceStatusData()
    }
    
    func loadCurrentBgData(forceRefresh: Bool) {

        // do not call refresh again if not needed
        guard forceRefresh || !NightscoutCacheService.singleton.hasCurrentNightscoutDataPendingRequests else {
            return
        }

        self.nightscoutData = NightscoutCacheService.singleton.loadCurrentNightscoutData(forceRefresh: forceRefresh) { [unowned self] result in
            
            guard let result = result else { return }
            
             dispatchOnMain { [unowned self] in
                guard self.active else { return }
                
                switch result {
                case .data(let newNightscoutData):
                    self.nightscoutData = newNightscoutData
                    calculateColors(nightscoutData: newNightscoutData)
                    self.active = false
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
    
    fileprivate func calculateColors(nightscoutData: NightscoutData) {
        
        self.sgvColor = Color(UIColorChanger.getBgColor(UnitsConverter.toDisplayUnits(nightscoutData.sgv)))
        self.sgvDeltaColor = Color(UIColorChanger.getDeltaLabelColor(
                UnitsConverter.toDisplayUnits(nightscoutData.bgdelta)))
        self.arrowColor = Color(
                UIColorChanger.getDeltaLabelColor(nightscoutData.bgdelta))
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
            self.temporaryTarget = "TT \(UnitsConverter.toDisplayUnits(temporaryTargetData.targetTop)) \(temporaryTargetData.activeUntilDate.remainingMinutes())m"
        } else {
            self.temporaryTarget = "TT --"
        }
    }
}
