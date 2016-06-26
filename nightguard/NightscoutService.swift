	//
//  ServiceBoundary.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 26.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation

/* All data that is read from nightscout is accessed using this boundary. */
class NightscoutService {
    
    static let singleton = NightscoutService()
    
    let ONE_DAY_IN_MICROSECONDS = Double(60*60*24*1000)
    
    /* Reads the last 20 historic blood glucose data from the nightscout server. */
    func readChartData(resultHandler : ([Int] -> Void)) {
        
        let baseUri = UserDefaultsRepository.readBaseUri()
        if baseUri == "" {
            return
        }
        
        // Get the current data from REST-Call
        let request : NSMutableURLRequest = NSMutableURLRequest(URL: NSURL(string: baseUri + "/api/v1/entries.json?count=20")!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 20)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                return
            }
            guard data != nil else {
                return
            }
            
            let jsonArray : NSArray = try!NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSArray
            var sgvValues = [Int]()
            for jsonDict in jsonArray {
                let sgv = jsonDict["sgv"] as? NSNumber
                if sgv != nil {
                    sgvValues.insert(Int(sgv!), atIndex: 0)
                }
            }
            resultHandler(sgvValues)
        };
        task.resume()
    }

    /* Reads the nightscout status of the backend. This is used to determine the configured
       Unit, whether it's mg/dL or mmol/l */
    func readStatus(resultHandler : (Units -> Void)) {
        
        let baseUri = UserDefaultsRepository.readBaseUri()
        if baseUri == "" {
            return
        }
        
        // Get the current data from REST-Call
        let request : NSMutableURLRequest = NSMutableURLRequest(URL: NSURL(string: baseUri + "/api/v1/status.json")!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 20)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
            
            guard error == nil else {
                return
            }
            guard data != nil else {
                return
            }
            
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)
                guard let jsonDict :NSDictionary = json as? NSDictionary else {
                    return
                }
                let settingsDict = jsonDict.objectForKey("settings") as! NSDictionary
                if (settingsDict.count > 0) {
                    
                    let unitsAsString = settingsDict.valueForKey("units") as! String
                    if unitsAsString == "mg/dL" {
                        resultHandler(Units.mgdl)
                    } else {
                        resultHandler(Units.mmol)
                    }
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
        task.resume()
    }
    
    /* Reads all data between two timestamps and limits the maximum return values to 300. */
    func readChartDataWithinPeriodOfTime(timestamp1 : NSDate, timestamp2 : NSDate, resultHandler : ([BloodSugar] -> Void)) {

        let baseUri = UserDefaultsRepository.readBaseUri()
        if baseUri == "" {
            return
        }
        
        let unixTimestamp1 : Double = timestamp1.timeIntervalSince1970 * 1000
        let unixTimestamp2 : Double = timestamp2.timeIntervalSince1970 * 1000
        
        // Get the current data from REST-Call
        let requestUri : String = "\(baseUri)/api/v1/entries?find[date][$gte]=\(unixTimestamp1)&find[date][$lte]=\(unixTimestamp2)&count=1200"
        guard let request : NSMutableURLRequest = NSMutableURLRequest(URL: NSURL(string: requestUri)!,
                                                                      cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 20) else {
            return
        }
        
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                return
            }
            guard data != nil else {
                return
            }
            
            let stringSgvData = String(data: data!, encoding: NSUTF8StringEncoding)!
            let sgvRows = stringSgvData.componentsSeparatedByString("\n")
            
            var bloodSugarArray = [BloodSugar]()
            for sgvRow in sgvRows {
                let sgvRowArray = sgvRow.componentsSeparatedByString("\t")
                if sgvRowArray.count > 2 && sgvRowArray[2] != "" {
                    let bloodSugar = BloodSugar(value: Float(sgvRowArray[2])!, timestamp: Double(sgvRowArray[1])!)
                    bloodSugarArray.insert(bloodSugar, atIndex: 0)
                }
            }
            resultHandler(bloodSugarArray)
        }
        task.resume()
    }
    
    /* Reads all values from the day before. This is used for comparison with the current values. */
    func readYesterdaysChartData(resultHandler : ([BloodSugar] -> Void)) {
        
        let calendar = NSCalendar.currentCalendar()
        let yesterday = TimeService.getYesterday()
        
        let startOfYesterday = calendar.startOfDayForDate(yesterday)
        let endOfYesterday = calendar.startOfDayForDate(TimeService.getToday())
        
        readChartDataWithinPeriodOfTime(startOfYesterday, timestamp2: endOfYesterday, resultHandler: resultHandler)
    }
    
    /* Reads all values from the last 4 days. The day part of the values is normalized to the first found day.
       The normalizing is done to easily paint the different days in one chart later on. */
    func readLast4DaysChartData(callbackHandler : ([[BloodSugar]] -> Void)) {
        
        let time4DaysAgo = TimeService.get4DaysAgo()
 
        let calendar = NSCalendar.currentCalendar()
        let startOf4DaysAgo = calendar.startOfDayForDate(time4DaysAgo)
        
        readChartDataWithinPeriodOfTime(startOf4DaysAgo, timestamp2: TimeService.getToday(), resultHandler: {(bgValues) -> Void in
            callbackHandler(self.extractDaysAndSetDayPartsToFirstDayFound(bgValues))
        })
    }
    
    /* convert [BloodSugar] to [[BloodSugar]] so that each array element contains all BloodSugar the belongs
       to the same day. */
    func extractDaysAndSetDayPartsToFirstDayFound(bgValues : [BloodSugar]) -> [[BloodSugar]] {
        var days : [[BloodSugar]] = []
        let calendar = NSCalendar.currentCalendar()
        
        var currentDayValues : [BloodSugar] = []
        var lastDay : Int? = nil
        var firstDayFound : Int? = nil
        for bgValue in bgValues {
            
            let day = calendar.components(.Day, fromDate: NSDate(timeIntervalSince1970: bgValue.timestamp / 1000)).day
            if day != lastDay {
                if firstDayFound == nil {
                    firstDayFound = day
                }
                lastDay = day
                // for the first bgValue (when lastDay is nil), we don't like to add
                // the empty currentDayValues to the result array
                if currentDayValues.count > 0 {
                    let copiedValues = currentDayValues
                    days.append(copiedValues)
                }
                currentDayValues = []
            }
            currentDayValues.append(changeDayTo(firstDayFound!, currentDay: day, bgValue: bgValue))
        }
        
        days.append(currentDayValues)
        return days
    }
    
    func changeDayTo(dayToSet : Int, currentDay : Int, bgValue : BloodSugar) -> BloodSugar {
        if dayToSet == currentDay {
            // The day already fits => nothing to do
            return bgValue
        }
        
        return BloodSugar.init(value: bgValue.value, timestamp: bgValue.timestamp + Double(dayToSet - currentDay) * ONE_DAY_IN_MICROSECONDS)
    }
    
    /* Reads all values from the last 2 Hours before. */
    func readLastTwoHoursChartData(resultHandler : ([BloodSugar] -> Void)) {
        
        let today = TimeService.getToday()
        let twoHoursBefore = today.dateByAddingTimeInterval(-60*120)
        
        readChartDataWithinPeriodOfTime(twoHoursBefore, timestamp2: today, resultHandler: resultHandler)
    }
    
    /* Reads the current blood glucose data that was planned to be displayed on a pebble watch. */
    func readCurrentDataForPebbleWatch(resultHandler : (NightscoutData -> Void)) {

        let baseUri = UserDefaultsRepository.readBaseUri()
        if (baseUri == "") {
            return
        }
        
        // Get the current data from REST-Call
        let request : NSMutableURLRequest = NSMutableURLRequest(URL: NSURL(string: baseUri + "/pebble")!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 20)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                return
            }
            guard data != nil else {
                return
            }

            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)
                guard let jsonDict :NSDictionary = json as? NSDictionary else {
                    return
                }
                let bgs : NSArray = jsonDict.objectForKey("bgs") as! NSArray
                if (bgs.count > 0) {
                    let currentBgs : NSDictionary = bgs.objectAtIndex(0) as! NSDictionary
                    
                    let sgv : NSString = currentBgs.objectForKey("sgv") as! NSString
                    let bgdelta = Float(String(currentBgs.objectForKey("bgdelta")!))
                    let time = currentBgs.objectForKey("datetime") as! NSNumber
                    
                    let nightscoutData = NightscoutData()
                    let battery : NSString? = currentBgs.objectForKey("battery") as? NSString
                    if battery == nil {
                        nightscoutData.battery = String("?")
                    } else {
                        nightscoutData.battery = String(battery!) + "%"
                    }

                    nightscoutData.sgv = String(sgv)
                    nightscoutData.bgdeltaString = self.direction(bgdelta!) + String(format: "%.1f", bgdelta!)
                    nightscoutData.bgdelta = bgdelta!
                    nightscoutData.time = time
                    
                    resultHandler(nightscoutData)
                }
            } catch {
                return
            }
        };
        task.resume()
    }
    
    private func direction(delta : Float) -> String {
        if (delta >= 0) {
            return "+"
        }
        return ""
    }
    
    private func formatTime(secondsSince01011970 : NSNumber) -> String {
        let timeFormatter = NSDateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dateString : String = timeFormatter.stringFromDate(NSDate(timeIntervalSince1970: secondsSince01011970.doubleValue / 1000))
        return dateString
    }
}