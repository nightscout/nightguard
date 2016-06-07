//
//  YesterdayComparisonValues.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 25.04.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

// Contains the blood values from the day before
class YesterdayBloodSugarService {
    
    static let singleton = YesterdayBloodSugarService()
    
    let ONE_DAY_IN_MICROSECONDS = Double(60*60*24*1000)
    
    var bloodSugarArray : [BloodSugar] = []
    
    func warmupCache() {
        if needsToBeRefreshed() {
            ServiceBoundary.singleton.readYesterdaysChartData({bloodValues -> Void in
                
                self.bloodSugarArray = bloodValues
            })
        }
    }
    
    func getYesterdaysValues(from : Double, to : Double) -> [BloodSugar]{
        if needsToBeRefreshed() {
            ServiceBoundary.singleton.readYesterdaysChartData({bloodValues -> Void in
                
                self.bloodSugarArray = bloodValues
            })
            // temporarily return empty values => since the new values are created
            return []
        } else {
            return filteredValues(from, to: to)
        }
    }

    /* Gets yesterdays blood values and transform these to the current day.
       Therefore they can be compared in one diagram. */
    func getYesterdaysValuesTransformedToCurrentDay(from : Double, to : Double) -> [BloodSugar]{
        
        let yesterdaysValues = getYesterdaysValues(from, to: to)
        var transformedValues : [BloodSugar] = []
        for yesterdaysValue in yesterdaysValues {
            let transformedValue = BloodSugar.init(value: yesterdaysValue.value, timestamp: yesterdaysValue.timestamp + ONE_DAY_IN_MICROSECONDS)
            transformedValues.append(transformedValue)
        }
        
        return transformedValues
    }
    
    func filteredValues(from : Double, to : Double) -> [BloodSugar] {
        var filteredValues : [BloodSugar] = []
        
        for bloodSugar in bloodSugarArray {
            if isInRangeRegardingHoursAndMinutes(bloodSugar, from: from, to: to) {
                filteredValues.append(bloodSugar)
            }
        }
        
        return filteredValues
    }
    
    private func isInRangeRegardingHoursAndMinutes(bloodSugar : BloodSugar, from : Double, to : Double) -> Bool {
        
        // set from / to time one day back in time
        // so the time is the only that is compared
        
        let yesterdayFrom = from - ONE_DAY_IN_MICROSECONDS
        let yesterdayTo = to - ONE_DAY_IN_MICROSECONDS
        
        return yesterdayFrom <= bloodSugar.timestamp && bloodSugar.timestamp <= yesterdayTo
    }
    
    private func needsToBeRefreshed() -> Bool {
        if bloodSugarArray.count == 0 {
            return true
        }
        
        return !TimeService.isYesterday(bloodSugarArray[0].timestamp)
    }
}