//
//  UserDefaults.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 27.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

struct NightguardDisplaySnapshot: Codable, Hashable {
    static let maxFreshAge: TimeInterval = 15 * 60

    struct BgValue: Codable, Hashable {
        let value: String
        let valueColorRed: Double
        let valueColorGreen: Double
        let valueColorBlue: Double
        let delta: String
        let timestamp: Double
        let arrow: String
    }

    let sgv: String
    let bgdeltaString: String
    let bgdeltaArrow: String
    let bgdelta: Double
    let timestamp: TimeInterval
    let battery: String
    let iob: String
    let cob: String
    let snoozedUntilTimestamp: TimeInterval
    let sgvColorRed: Double
    let sgvColorGreen: Double
    let sgvColorBlue: Double
    let bgdeltaColorRed: Double
    let bgdeltaColorGreen: Double
    let bgdeltaColorBlue: Double
    let createdAt: Date
    let lastBGValues: [BgValue]

    init(
        sgv: String,
        bgdeltaString: String,
        bgdeltaArrow: String,
        bgdelta: Double,
        timestamp: TimeInterval,
        battery: String,
        iob: String,
        cob: String,
        snoozedUntilTimestamp: TimeInterval,
        sgvColorRed: Double,
        sgvColorGreen: Double,
        sgvColorBlue: Double,
        bgdeltaColorRed: Double,
        bgdeltaColorGreen: Double,
        bgdeltaColorBlue: Double,
        createdAt: Date,
        lastBGValues: [BgValue]
    ) {
        self.sgv = sgv
        self.bgdeltaString = bgdeltaString
        self.bgdeltaArrow = bgdeltaArrow
        self.bgdelta = bgdelta
        self.timestamp = timestamp
        self.battery = battery
        self.iob = iob
        self.cob = cob
        self.snoozedUntilTimestamp = snoozedUntilTimestamp
        self.sgvColorRed = sgvColorRed
        self.sgvColorGreen = sgvColorGreen
        self.sgvColorBlue = sgvColorBlue
        self.bgdeltaColorRed = bgdeltaColorRed
        self.bgdeltaColorGreen = bgdeltaColorGreen
        self.bgdeltaColorBlue = bgdeltaColorBlue
        self.createdAt = createdAt
        self.lastBGValues = lastBGValues
    }

    var date: Date {
        Date(timeIntervalSince1970: timestamp / 1000)
    }

    func isFresh(referenceDate: Date = Date(), maxAge: TimeInterval = maxFreshAge) -> Bool {
        referenceDate.timeIntervalSince(date) <= maxAge
    }

    static func make(from data: NightscoutData, previousValues: [BloodSugar] = []) -> NightguardDisplaySnapshot {
        let displaySgv = UnitsConverter.mgdlToDisplayUnits(data.sgv)
        let displayDelta = UnitsConverter.mgdlToDisplayUnitsWithSign("\(data.bgdelta)")
        let sgvColor = UIColorChanger.getBgColor(displaySgv)
        let bgdeltaColor = UIColorChanger.getDeltaLabelColor(data.bgdelta)
        let sgvComponents = colorComponents(from: sgvColor)
        let bgdeltaComponents = colorComponents(from: bgdeltaColor)
        let fallbackValue = BgValue(
            value: displaySgv,
            valueColorRed: sgvComponents.red,
            valueColorGreen: sgvComponents.green,
            valueColorBlue: sgvComponents.blue,
            delta: displayDelta,
            timestamp: data.time.doubleValue,
            arrow: data.bgdeltaArrow
        )
        let lastBGValues = makeLastBGValues(
            from: historyValues(previousValues, including: data),
            fallbackValue: fallbackValue
        )

        return NightguardDisplaySnapshot(
            sgv: displaySgv,
            bgdeltaString: displayDelta,
            bgdeltaArrow: data.bgdeltaArrow,
            bgdelta: Double(data.bgdelta),
            timestamp: data.time.doubleValue,
            battery: data.battery,
            iob: data.iob,
            cob: data.cob,
            snoozedUntilTimestamp: AlarmRule.snoozedUntilTimestamp.value,
            sgvColorRed: sgvComponents.red,
            sgvColorGreen: sgvComponents.green,
            sgvColorBlue: sgvComponents.blue,
            bgdeltaColorRed: bgdeltaComponents.red,
            bgdeltaColorGreen: bgdeltaComponents.green,
            bgdeltaColorBlue: bgdeltaComponents.blue,
            createdAt: Date(),
            lastBGValues: lastBGValues
        )
    }

    static func makeLastBGValues(from bloodSugarValues: [BloodSugar], fallbackValue: BgValue? = nil) -> [BgValue] {
        let bgEntries = bloodSugarValues
            .filter { $0.isValid }
            .sorted { $0.timestamp < $1.timestamp }
            .map { bloodSugar in
                SnapshotBgEntry(
                    value: UnitsConverter.mgdlToDisplayUnits(String(bloodSugar.value)),
                    timestamp: bloodSugar.timestamp,
                    arrow: bloodSugar.arrow
                )
            }

        let reducedEntries = Array(bgEntries.suffix(4))
        let values = calculateDeltaValues(reducedEntries).reversed()

        if values.isEmpty, let fallbackValue {
            return [fallbackValue]
        }

        return Array(values)
    }

    static func historyValues(_ bloodSugarValues: [BloodSugar], including data: NightscoutData) -> [BloodSugar] {
        guard let currentValue = Float(data.sgv),
              BloodSugar.isValid(value: currentValue),
              data.time.doubleValue > 0 else {
            return bloodSugarValues
        }

        let currentTimestamp = data.time.doubleValue
        let currentBloodSugar = BloodSugar(
            value: currentValue,
            timestamp: currentTimestamp,
            isMeteredBloodGlucoseValue: false,
            arrow: data.bgdeltaArrow
        )

        return bloodSugarValues
            .filter { abs($0.timestamp - currentTimestamp) > 0.5 }
            + [currentBloodSugar]
    }

    private struct SnapshotBgEntry {
        let value: String
        let timestamp: Double
        let arrow: String
    }

    private static func calculateDeltaValues(_ reducedEntries: [SnapshotBgEntry]) -> [BgValue] {
        var preceedingEntry: SnapshotBgEntry?
        var newEntries: [BgValue] = []

        for bgEntry in reducedEntries {
            if preceedingEntry?.value != nil {
                let v1AsFloat = Float(bgEntry.value) ?? Float.zero
                let v2AsFloat = Float(preceedingEntry?.value ?? bgEntry.value) ?? v1AsFloat
                let valueColor = UIColorChanger.getBgColor(bgEntry.value)
                let valueComponents = colorComponents(from: valueColor)

                newEntries.append(
                    BgValue(
                        value: bgEntry.value,
                        valueColorRed: valueComponents.red,
                        valueColorGreen: valueComponents.green,
                        valueColorBlue: valueComponents.blue,
                        delta: Float(v1AsFloat - v2AsFloat).cleanSignedValue,
                        timestamp: bgEntry.timestamp,
                        arrow: bgEntry.arrow
                    )
                )
            }

            preceedingEntry = bgEntry
        }

        return newEntries
    }

    private static func colorComponents(from color: UIColor) -> (red: Double, green: Double, blue: Double) {
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }

    enum CodingKeys: String, CodingKey {
        case sgv
        case bgdeltaString
        case bgdeltaArrow
        case bgdelta
        case timestamp
        case battery
        case iob
        case cob
        case snoozedUntilTimestamp
        case sgvColorRed
        case sgvColorGreen
        case sgvColorBlue
        case bgdeltaColorRed
        case bgdeltaColorGreen
        case bgdeltaColorBlue
        case createdAt
        case lastBGValues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sgv = try container.decode(String.self, forKey: .sgv)
        self.bgdeltaString = try container.decode(String.self, forKey: .bgdeltaString)
        self.bgdeltaArrow = try container.decode(String.self, forKey: .bgdeltaArrow)
        self.bgdelta = try container.decode(Double.self, forKey: .bgdelta)
        self.timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        self.battery = try container.decode(String.self, forKey: .battery)
        self.iob = try container.decode(String.self, forKey: .iob)
        self.cob = try container.decode(String.self, forKey: .cob)
        self.snoozedUntilTimestamp = try container.decode(TimeInterval.self, forKey: .snoozedUntilTimestamp)
        self.sgvColorRed = try container.decode(Double.self, forKey: .sgvColorRed)
        self.sgvColorGreen = try container.decode(Double.self, forKey: .sgvColorGreen)
        self.sgvColorBlue = try container.decode(Double.self, forKey: .sgvColorBlue)
        self.bgdeltaColorRed = try container.decode(Double.self, forKey: .bgdeltaColorRed)
        self.bgdeltaColorGreen = try container.decode(Double.self, forKey: .bgdeltaColorGreen)
        self.bgdeltaColorBlue = try container.decode(Double.self, forKey: .bgdeltaColorBlue)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.lastBGValues = try container.decodeIfPresent([BgValue].self, forKey: .lastBGValues) ?? [
            BgValue(
                value: sgv,
                valueColorRed: sgvColorRed,
                valueColorGreen: sgvColorGreen,
                valueColorBlue: sgvColorBlue,
                delta: bgdeltaString,
                timestamp: timestamp,
                arrow: bgdeltaArrow
            )
        ]
    }
}

// Repository to store BgData using the NSUserDefaults
class NightscoutDataRepository {
    
    static let singleton = NightscoutDataRepository()
    
    struct Constants {
        static let currentBgData = "currentBgData"
        static let todaysBgData = "todaysBgData"
        static let yesterdaysBgData = "yesterdaysBgData"
        static let yesterdaysBgDataRaw = "yesterdaysBgDataRaw"
        static let yesterdaysDayOfTheYear = "yesterdaysDayOfTheYear"
        static let cannulaChangeTime = "cannulaChangeTime"
        static let sensorChangeTime = "sensorChangeTime"
        static let batteryChangeTime = "batteryChangeTime"
        static let deviceStatus = "deviceStatus"
        static let temporaryTarget = "temporaryTarget"
        static let latestDisplaySnapshot = "latestDisplaySnapshot"
    }
    
    var isEmpty: Bool {
        return loadYesterdaysBgData().isEmpty && loadTodaysBgData().isEmpty
    }
    
    func clearAll() {
         let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.removeObject(forKey: Constants.currentBgData)
        defaults?.removeObject(forKey: Constants.todaysBgData)
        defaults?.removeObject(forKey: Constants.yesterdaysBgData)
        defaults?.removeObject(forKey: Constants.yesterdaysBgDataRaw)
        defaults?.removeObject(forKey: Constants.yesterdaysDayOfTheYear)
        defaults?.removeObject(forKey: Constants.latestDisplaySnapshot)
        // this shouldn't be necessary anymore - remove it later
        defaults?.synchronize()
    }
    
    func storeCurrentNightscoutData(_ bgData : NightscoutData) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        NSKeyedArchiver.setClassName("NightscoutData", for: NightscoutData.self)
        try?
            defaults?.set(
                NSKeyedArchiver.archivedData(withRootObject: bgData, requiringSecureCoding: true),
                forKey: Constants.currentBgData)
    }
    
    func loadCurrentNightscoutData() -> NightscoutData {
        
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return NightscoutData()
        }
        
        guard let data = defaults.object(forKey: Constants.currentBgData) as? Data else {
            return NightscoutData()
        }
        
        NSKeyedUnarchiver.setClass(NightscoutData.self, forClassName: "NightscoutData")
        guard let nightscoutData = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NightscoutData.self, NSString.self, NSNumber.self], from: data)) as? NightscoutData else {
            return NightscoutData()
        }
        return nightscoutData
    }

    func storeLatestDisplaySnapshot(_ snapshot: NightguardDisplaySnapshot) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        let data = try? JSONEncoder().encode(snapshot)
        defaults?.set(data, forKey: Constants.latestDisplaySnapshot)
    }

    @discardableResult
    func storeLatestDisplaySnapshot(from data: NightscoutData, previousValues: [BloodSugar] = []) -> NightguardDisplaySnapshot {
        let historyValues = previousValues.isEmpty ? loadTodaysBgData() : previousValues
        let snapshot = NightguardDisplaySnapshot.make(from: data, previousValues: historyValues)
        storeLatestDisplaySnapshot(snapshot)
        return snapshot
    }

    func loadLatestDisplaySnapshot() -> NightguardDisplaySnapshot? {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID),
              let data = defaults.object(forKey: Constants.latestDisplaySnapshot) as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(NightguardDisplaySnapshot.self, from: data)
    }
    
    func storeTodaysBgData(_ todaysBgData : [BloodSugar]) {
        
        storeBgData(keyName: Constants.todaysBgData, todaysBgData)
    }
    
    func loadTodaysBgData() -> [BloodSugar] {
        
        return loadBgData(keyName: Constants.todaysBgData)
    }
    
    func storeYesterdaysBgData(_ yesterdaysBgData : [BloodSugar]) {
        
        storeBgData(keyName: Constants.yesterdaysBgData, yesterdaysBgData)
    }
    
    func loadYesterdaysBgData() -> [BloodSugar] {
        
        return loadBgData(keyName: Constants.yesterdaysBgData)
    }

    func storeYesterdaysBgDataRaw(_ yesterdaysBgDataRaw : [BloodSugar]) {
        
        storeBgData(keyName: Constants.yesterdaysBgDataRaw, yesterdaysBgDataRaw)
    }
    
    func loadYesterdaysBgDataRaw() -> [BloodSugar] {
        
        return loadBgData(keyName: Constants.yesterdaysBgDataRaw)
    }
    
    func loadYesterdaysDayOfTheYear() -> Int {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return -1
        }
        
        return defaults.integer(forKey: Constants.yesterdaysDayOfTheYear)
    }
    
    func storeYesterdaysDayOfTheYear(yesterdaysDayOfTheYear : Int) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.set(yesterdaysDayOfTheYear, forKey: Constants.yesterdaysDayOfTheYear)
    }
    
    func loadCannulaChangeTime() -> Date {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return Date()
        }
        
        if let cannulaChangeTime = defaults.object(forKey: Constants.cannulaChangeTime) as? Date {
            return cannulaChangeTime
        }
        
        if let cannulaChangeTime = defaults.object(forKey: Constants.cannulaChangeTime) as? Double {
            return Date(timeIntervalSince1970: cannulaChangeTime)
        }
        
        return Date()
    }
    
    func storeCannulaChangeTime(cannulaChangeTime : Date) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.set(cannulaChangeTime.timeIntervalSince1970, forKey: Constants.cannulaChangeTime)
    }
    
    func loadSensorChangeTime() -> Date {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return Date()
        }
        
        if let sensorChangeTime = defaults.object(forKey: Constants.sensorChangeTime) as? Date {
            return sensorChangeTime
        }
        
        if let sensorChangeTime = defaults.object(forKey: Constants.sensorChangeTime) as? Double {
            return Date(timeIntervalSince1970: sensorChangeTime)
        }
        
        return Date()
    }
    
    func storeSensorChangeTime(sensorChangeTime : Date) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.set(sensorChangeTime.timeIntervalSince1970, forKey: Constants.sensorChangeTime)
    }
    
    func loadBatteryChangeTime() -> Date {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return Date()
        }
        
        if let batteryChangeTime = defaults.object(forKey: Constants.batteryChangeTime) as? Date {
            return batteryChangeTime
        }
        
        if let batteryChangeTime = defaults.object(forKey: Constants.batteryChangeTime) as? Double {
            return Date(timeIntervalSince1970: batteryChangeTime)
        }
        
        return Date()
    }
    
    func storeBatteryChangeTime(batteryChangeTime : Date) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.set(batteryChangeTime.timeIntervalSince1970, forKey: Constants.batteryChangeTime)
    }
    
    func storeDeviceStatusData(deviceStatusData : DeviceStatusData) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        NSKeyedArchiver.setClassName("DeviceStatusData", for: DeviceStatusData.self)
        defaults?.set(try? NSKeyedArchiver.archivedData(withRootObject: deviceStatusData, requiringSecureCoding: true), forKey: Constants.deviceStatus)
    }
    
    func loadDeviceStatusData() -> DeviceStatusData {
        
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return DeviceStatusData()
        }
        
        guard let data = defaults.object(forKey: Constants.deviceStatus) as? Data else {
            return DeviceStatusData()
        }
        
        NSKeyedUnarchiver.setClass(DeviceStatusData.self, forClassName: "DeviceStatusData")
        guard let deviceStatusData = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [DeviceStatusData.self, NSString.self, NSNumber.self, NSDate.self], from: data)) as? DeviceStatusData else {
            return DeviceStatusData()
        }
        return deviceStatusData
    }
    
    func storeTemporaryTargetData(temporaryTargetData : TemporaryTargetData) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        NSKeyedArchiver.setClassName("TemporaryTargetData", for: TemporaryTargetData.self)
        defaults?.set(try? NSKeyedArchiver.archivedData(withRootObject: temporaryTargetData, requiringSecureCoding: true), forKey: Constants.temporaryTarget)
    }
    
    func loadTemporaryTargetData() -> TemporaryTargetData {
        
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return TemporaryTargetData()
        }
        
        guard let data = defaults.object(forKey: Constants.temporaryTarget) as? Data else {
            return TemporaryTargetData()
        }
        
        NSKeyedUnarchiver.setClass(TemporaryTargetData.self, forClassName: "TemporaryTargetData")
        guard let temporaryTargetData = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [TemporaryTargetData.self, NSString.self, NSNumber.self, NSDate.self], from: data)) as? TemporaryTargetData else {
            return TemporaryTargetData()
        }
        return temporaryTargetData
    }
    
    fileprivate func storeBgData(keyName : String, _ bgData : [BloodSugar]) {
        
        print("Storing \(bgData.count) using key \(keyName)")
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults?.set(
            try? NSKeyedArchiver.archivedData(withRootObject: bgData, requiringSecureCoding: true),
            forKey: keyName)
    }
    
    fileprivate func loadBgData(keyName : String) -> [BloodSugar] {
        
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            // Nothing has been stored before => return dummy-Data
            return []
        }
        
        guard let data = defaults.object(forKey: keyName) as? Data else {
            return []
        }
        
        guard let bgData = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, BloodSugar.self, NSString.self], from: data)) as? [BloodSugar] else {
            return []
        }
        return bgData
    }
}
