	//
//  ServiceBoundary.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 26.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation

/* All data that is read from nightscout is accessed using this boundary. */
class ServiceBoundary {
    
    static let singleton = ServiceBoundary()
    
    var baseUri : String {
        get {
            if self.baseUri != "" {
                return self.baseUri
            } else {
                return UserDefaults.getBaseUri()
            }
        }
        set {}
    }
    /* Reads the last 20 historic blood glucose data from the nightscout server. */
    func readChartData(resultHandler : ([Int] -> Void)) {
        
        let baseUri = UserDefaults.getBaseUri()
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

    /* Reads all data between two timestamps and limits the maximum return values to 300. */
    func readChartDataWithinPeriodOfTime(timestamp1 : NSDate, timestamp2 : NSDate, resultHandler : ([BloodSugar] -> Void)) {
        
        let baseUri = UserDefaults.getBaseUri()
        if baseUri == "" {
            return
        }
        
        let unixTimestamp1 : Double = timestamp1.timeIntervalSince1970 * 1000
        let unixTimestamp2 : Double = timestamp2.timeIntervalSince1970 * 1000
        
        // Get the current data from REST-Call
        let requestUri : String = "\(baseUri)/api/v1/entries?find[date][$gte]=\(unixTimestamp1)&find[date][$lte]=\(unixTimestamp2)&count=300"
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
                    let bloodSugar = BloodSugar(value: Int(sgvRowArray[2])!, timestamp: Double(sgvRowArray[1])!)
                    bloodSugarArray.insert(bloodSugar, atIndex: 0)
                }
            }
            resultHandler(bloodSugarArray)
        };
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
    
    /* Reads all values from the last 2 Hours before. */
    func readLastTwoHoursChartData(resultHandler : ([BloodSugar] -> Void)) {
        
        let currentTime = TimeService.getToday()
        let twoHoursBefore = currentTime.dateByAddingTimeInterval(-60*120)
        
        readChartDataWithinPeriodOfTime(twoHoursBefore, timestamp2: currentTime, resultHandler: resultHandler)
    }
    
    /* Reads the current blood glucose data that was planned to be displayed on a pebble watch. */
    func readCurrentDataForPebbleWatch(resultHandler : (NightscoutData -> Void)) {
        
        let baseUri = UserDefaults.getBaseUri()
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
                    let bgdelta = currentBgs.objectForKey("bgdelta") as! NSNumber
                    let time = currentBgs.objectForKey("datetime") as! NSNumber
                    let battery = currentBgs.objectForKey("battery") as! NSString
                    
                    let nightscoutData = NightscoutData()
                    nightscoutData.sgv = String(sgv)
                    nightscoutData.bgdeltaString = self.direction(bgdelta) + String(bgdelta)
                    nightscoutData.bgdelta = bgdelta
                    nightscoutData.time = time
                    nightscoutData.battery = String(battery) + "%"
                    
                    resultHandler(nightscoutData)
                }
            } catch {
                return
            }
        };
        task.resume()
    }
    
    private func direction(delta : NSNumber) -> String {
        if (delta.intValue >= 0) {
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