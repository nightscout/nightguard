//
//  NightscoutCacheService.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 06.11.17.
//  Copyright © 2017 private. All rights reserved.
//

import Foundation

// This is a facade in front of the nightscout service. It is used to reduce the
// amount of turnarounds to the real backend to a minimum.
class NightscoutCacheService: NSObject {
    
    static let singleton = NightscoutCacheService()
    
    var isEmpty: Bool {
        return (yesterdaysBgData ?? []).isEmpty && (todaysBgData ?? []).isEmpty
    }
    
    fileprivate var todaysBgData : [BloodSugar]? = nil
    fileprivate var yesterdaysBgData : [BloodSugar]? = nil
    fileprivate var yesterdaysDayOfTheYear : Int? = nil
    fileprivate var currentNightscoutData : NightscoutData? = nil
    
    fileprivate var cannulaAge : Date? = nil
    fileprivate var sensorAge : Date? = nil
    fileprivate var pumpBattery : Int? = nil
    
    fileprivate var newDataReceived : Bool = false
    fileprivate let ONE_DAY_IN_MICROSECONDS = Double(60*60*24*1000)
    
    // housekeeping of pending requests
    fileprivate var todaysBgDataTasks: [URLSessionTask] = []
    fileprivate var yesterdaysBgDataTasks: [URLSessionTask] = []
    fileprivate var currentNightscoutDataTasks: [URLSessionTask] = []
    fileprivate var temporaryTargetData: TemporaryTargetData = TemporaryTargetData()
    
    // are there any running "todays bg data" requests?
    var hasTodaysBgDataPendingRequests: Bool {
        return todaysBgDataTasks.contains(where: { task in task.state == .running })
    }

    // are there any running "yesterdays bg data" requests?
    var hasYesterdaysBgDataPendingRequests: Bool {
        return yesterdaysBgDataTasks.contains(where: { task in task.state == .running })
    }

    // are there any running "current nightscout data" requests?
    var hasCurrentNightscoutDataPendingRequests: Bool {
        return currentNightscoutDataTasks.contains(where: { task in task.state == .running })
    }

    // During background updates, this value is modified from the ExtensionDelegate
    func updateCurrentNightscoutData(newNightscoutData : NightscoutData) {
        currentNightscoutData = newNightscoutData
        NightscoutDataRepository.singleton.storeCurrentNightscoutData(newNightscoutData)
    }
    
    func resetCache() {
        todaysBgData = nil
        yesterdaysBgData = nil
        yesterdaysDayOfTheYear = nil
        currentNightscoutData = nil
        
        NightscoutDataRepository.singleton.clearAll()
    }
    
    func getCannulaChangeTime() -> Date {
        
        NightscoutService.singleton.readLastTreatementEventTimestamp(eventType: .cannulaChange, daysToGoBackInTime: 3, resultHandler: { (cannulaChangeTime: Date) in
                NightscoutDataRepository.singleton.storeCannulaChangeTime(cannulaChangeTime: cannulaChangeTime)
            })
        
        return NightscoutDataRepository.singleton.loadCannulaChangeTime()
    }
    
    func getSensorChangeTime() -> Date {
        NightscoutService.singleton.readLastTreatementEventTimestamp(eventType: .sensorStart, daysToGoBackInTime: 14, resultHandler: { (sensorChangeTime: Date) in
                NightscoutDataRepository.singleton.storeSensorChangeTime(sensorChangeTime: sensorChangeTime)
            })
        return NightscoutDataRepository.singleton.loadSensorChangeTime()
    }
    
    func getPumpBatteryChangeTime() ->  Date {
        NightscoutService.singleton.readLastTreatementEventTimestamp(eventType: .pumpBatteryChange, daysToGoBackInTime: 40, resultHandler: { (batteryChangeTime: Date) in
                NightscoutDataRepository.singleton.storeBatteryChangeTime(batteryChangeTime: batteryChangeTime)
            })
        
        return NightscoutDataRepository.singleton.loadBatteryChangeTime()
    }
    
    func getDeviceStatusData(_ resultHandler : @escaping (DeviceStatusData) -> Void) -> DeviceStatusData {
            NightscoutService.singleton.readDeviceStatus(resultHandler: { (deviceStatusData: DeviceStatusData) in
                    NightscoutDataRepository.singleton.storeDeviceStatusData(deviceStatusData: deviceStatusData)
                resultHandler(deviceStatusData)
        })
        
        return NightscoutDataRepository.singleton.loadDeviceStatusData()
    }
    
    func getCurrentNightscoutData() -> NightscoutData {
        
        if (currentNightscoutData == nil) {
            return NightscoutData.init()
        }
        return currentNightscoutData!
    }
    
    func getTemporaryTargetData() -> TemporaryTargetData {
        
        NightscoutService.singleton.readLastTemporaryTarget(daysToGoBackInTime: 1, resultHandler:  { (temporaryTargetData: TemporaryTargetData?) in
            
                if let temporaryTargetData = temporaryTargetData {
                    NightscoutDataRepository.singleton.storeTemporaryTargetData(temporaryTargetData: temporaryTargetData)
                }
            })
        
        return NightscoutDataRepository.singleton.loadTemporaryTargetData()
    }
    
    func getTodaysBgData() -> [BloodSugar] {
        if todaysBgData == nil {
            return []
        }
        return todaysBgData!
    }
    
    func getYesterdaysBgData() -> [BloodSugar] {
        if yesterdaysBgData == nil {
            return []
        }
        return yesterdaysBgData!
    }
    
    // Returns true, if the size of one array changed
    func valuesChanged() -> Bool {
        
        if newDataReceived {
            newDataReceived = false;
            return true
        }
        
        return false
    }
    
    func loadCurrentNightscoutData(forceRefresh: Bool, _ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>?) -> Void) -> NightscoutData {
    
        if currentNightscoutData == nil {
            currentNightscoutData = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        }
        
        checkIfRefreshIsNeeded(resultHandler, forceRefresh: forceRefresh)
        
        return currentNightscoutData!
    }
    
    func loadCurrentNightscoutData(_ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>?) -> Void) -> NightscoutData {
        return loadCurrentNightscoutData(forceRefresh: false, resultHandler)
    }
    
    // Reads the blood glucose data from today
    func loadTodaysData(_ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>?) -> Void)
        -> [BloodSugar] {
        
        if todaysBgData == nil {
           todaysBgData = NightscoutDataRepository.singleton.loadTodaysBgData()
        }
        
        todaysBgData = removeYesterdaysEntries(bgValues: todaysBgData!)
        
        if todaysBgData!.count == 0 || currentNightscoutData == nil || currentNightscoutData!.isOlderThan5Minutes()
            || currentNightscoutWasFetchedInBackground(todaysBgData: todaysBgData!) {
            
            if let task = NightscoutService.singleton.readTodaysChartData(oldValues: todaysBgData!, { [unowned self] (result: NightscoutRequestResult<[BloodSugar]>) in
                
                if case .data(let todaysBgData) = result {
                    self.newDataReceived = true
                
                    self.todaysBgData = todaysBgData
                    NightscoutDataRepository.singleton.storeTodaysBgData(todaysBgData)
                }
                
                resultHandler(result)
            }) {
                // cleanup (delete not running tasks) and add the current started one
                todaysBgDataTasks.removeAll(where: { task in task.state != .running })
                todaysBgDataTasks.append(task)
            } else {
                resultHandler(nil)
            }
        } else {
            resultHandler(nil)
        }
            
        return todaysBgData!
    }
    
    fileprivate func currentNightscoutWasFetchedInBackground(todaysBgData : [BloodSugar]) -> Bool {
        
        // consider also the case when the current nightscout data is newer than newest 
        // "todays data" (are out of sync because probably the ns data was obtained 
        // while the app was in background)
        return currentNightscoutData!.time.doubleValue > (todaysBgData.last?.timestamp ?? 0)
    }
    
    fileprivate func removeYesterdaysEntries(bgValues : [BloodSugar]) -> [BloodSugar] {
        
        var todaysValues : [BloodSugar] = []
        
        let startOfCurrentDay = TimeService.getStartOfCurrentDay()
        
        for bgValue in bgValues {
            if bgValue.timestamp > startOfCurrentDay {
                todaysValues.append(bgValue)
            }
        }
        
        return todaysValues
    }
    
    // Reads the blood glucose data from yesterday
    func loadYesterdaysData(_ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>?) -> Void)
        -> [BloodSugar] {
        
        if yesterdaysBgData == nil {
            yesterdaysBgData = NightscoutDataRepository.singleton.loadYesterdaysBgData()
            yesterdaysDayOfTheYear = NightscoutDataRepository.singleton.loadYesterdaysDayOfTheYear()
        }
        
        if yesterdaysBgData!.count == 0 || currentNightscoutData == nil || yesterdaysValuesAreOutdated() {
            
            if let task = NightscoutService.singleton.readYesterdaysChartData({ [unowned self] (result: NightscoutRequestResult<[BloodSugar]>) in
                
                if case .data(let yesterdaysValues) = result {
                    self.newDataReceived = true
                    
                    // transform the yesterdays values to the current day, so that they can be easily displayed in
                    // one diagram
                    self.yesterdaysBgData = self.transformToCurrentDay(yesterdaysValues: yesterdaysValues)
                    NightscoutDataRepository.singleton.storeYesterdaysBgData(self.yesterdaysBgData!)
                    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                    self.yesterdaysDayOfTheYear = Calendar.current.ordinality(of: .day, in: .year, for: yesterday)!
                    NightscoutDataRepository.singleton.storeYesterdaysDayOfTheYear(yesterdaysDayOfTheYear: self.yesterdaysDayOfTheYear!)
                    
                    resultHandler(.data(self.yesterdaysBgData!))
                } else {
                    resultHandler(result)
                }
            }) {
                // cleanup (delete not running tasks) and add the current started one
                yesterdaysBgDataTasks.removeAll(where: { task in task.state != .running })
                yesterdaysBgDataTasks.append(task)
            } else {
                resultHandler(nil)
            }
        } else {
            resultHandler(nil)
        }
            
        return yesterdaysBgData!
    }
    
    // check if the stored yesterdaysvalues are from a day before
    fileprivate func yesterdaysValuesAreOutdated() -> Bool {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let newYesterdayDayOfTheYear = Calendar.current.ordinality(of: .day, in: .year, for: yesterday)!
        
        return newYesterdayDayOfTheYear != yesterdaysDayOfTheYear
    }
    
    fileprivate func transformToCurrentDay(yesterdaysValues : [BloodSugar]) -> [BloodSugar] {
        var transformedValues : [BloodSugar] = []
        for yesterdaysValue in yesterdaysValues {
            let transformedValue = BloodSugar.init(value: yesterdaysValue.value, timestamp: yesterdaysValue.timestamp + self.ONE_DAY_IN_MICROSECONDS)
            transformedValues.append(transformedValue)
        }
        
        return transformedValues
    }
    
    fileprivate func checkIfRefreshIsNeeded(_ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>?) -> Void, forceRefresh: Bool = false) {
        
        guard forceRefresh || currentNightscoutData!.isOlderThan5Minutes() else {
            resultHandler(nil)
            return
        }
        
        if let task = NightscoutService.singleton.readCurrentDataForPebbleWatch ({ [unowned self] (result: NightscoutRequestResult<NightscoutData>) in
            
            if case .data(let newNightscoutData) = result {
                self.currentNightscoutData = newNightscoutData
            
                NightscoutDataRepository.singleton.storeCurrentNightscoutData(self.currentNightscoutData!)
            }
            
            resultHandler(result)
        }) {
            // cleanup (delete not running tasks) and add the current started one
            currentNightscoutDataTasks.removeAll(where: { task in task.state != .running })
            currentNightscoutDataTasks.append(task)
        } else {
            resultHandler(nil)
        }
    }
}


// HACK for updating the today's data from Test Cases; the problem is that
// from tests the NightscoutDataRepository.loadTodaysBgData will fail unarchiving the [BloodSugar]
// data, even if stored correctly...
extension NightscoutCacheService {
    func updateTodaysBgDataForTesting(_ data: [BloodSugar]) {
        self.todaysBgData = data
    }
}
