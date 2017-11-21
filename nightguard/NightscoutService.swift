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
    let DIRECTIONS = ["-", "↑↑", "↑", "↖︎", "→", "↘︎", "↓", "↓↓", "-", "-"]
    
    /* Reads the last 20 historic blood glucose data from the nightscout server. */
    func readChartData(_ resultHandler : @escaping (([Int]) -> Void)) {
        
        let baseUri = UserDefaultsRepository.readBaseUri()
        if baseUri == "" {
            return
        }

        // Get the current data from REST-Call
        let request = URLRequest(url: URL(string: baseUri + "/api/v1/entries.json?count=20")!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20) as URLRequest
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            guard error == nil else {
                return
            }
            guard data != nil else {
                return
            }
            
            DispatchQueue.main.async {
                let jsonArray : [String:Any] = try!JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as! [String:Any]
                var sgvValues = [Int]()
                for (key, value) in jsonArray {
                    if key == "sqv" {
                        sgvValues.insert(value as! Int, at: 0)
                    }
                }
                resultHandler(sgvValues)
            }
        }) ;
        task.resume()
    }

    /* Reads the nightscout status from the backend. This is used to determine the configured
       Unit, whether it's mg/dL or mmol/l */
    func readStatus(_ resultHandler : @escaping ((Units) -> Void)) {
        
        let baseUri = UserDefaultsRepository.readBaseUri()
        if baseUri == "" {
            return
        }
        
        // Get the current data from REST-Call
        let request = URLRequest(url: URL(string: baseUri + "/api/v1/status.json")!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            
            guard error == nil else {
                return
            }
            guard data != nil else {
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
                    guard let jsonDict :NSDictionary = json as? NSDictionary else {
                        return
                    }
                    let settingsDict = jsonDict.object(forKey: "settings") as! NSDictionary
                    if (settingsDict.count > 0) {
                        
                        let unitsAsString = settingsDict.value(forKey: "units") as! String
                        if unitsAsString.lowercased() == "mg/dl" {
                            resultHandler(Units.mgdl)
                        } else {
                            resultHandler(Units.mmol)
                        }
                    }
                } catch let error as NSError {
                    print(error.localizedDescription)
                }
            }
        }) 
        task.resume()
    }
    
    /* Reads all data between two timestamps and limits the maximum return values to 300. */
    func readChartDataWithinPeriodOfTime(oldValues : [BloodSugar], _ timestamp1 : Date, timestamp2 : Date, resultHandler : @escaping (([BloodSugar]) -> Void)) {

        let baseUri = UserDefaultsRepository.readBaseUri()
        if baseUri == "" {
            return
        }
        
        let unixTimestamp1 : Double = timestamp1.timeIntervalSince1970 * 1000
        let unixTimestamp2 : Double = timestamp2.timeIntervalSince1970 * 1000
        
        // Get the current data from REST-Call
        let requestUri : String = "\(baseUri)/api/v1/entries?find[date][$gt]=\(unixTimestamp1)&find[date][$lte]=\(unixTimestamp2)&count=400"
        let request =
            URLRequest(url: URL(string: requestUri)!,
                            cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                return
            }
            guard data != nil else {
                print("The received data was nil...")
                return
            }
        
            let stringSgvData = String(data: data!, encoding: String.Encoding.utf8)!
            let sgvRows = stringSgvData.components(separatedBy: "\n")
            var timestampColumn : Int = 1
            var bloodSugarColumn : Int = 2
        
            var bloodSugarArray = [BloodSugar]()
            for sgvRow in sgvRows {
                let sgvRowArray = sgvRow.components(separatedBy: "\t")
            
                if sgvRowArray.count > 2 && sgvRowArray[2] != "" {
                    // Nightscout return for some versions
                    if self.isDateColumn(sgvRowArray[1]) {
                        timestampColumn = 2
                        bloodSugarColumn = 3
                    }
                
                    let bloodSugar = BloodSugar(value: Float(sgvRowArray[bloodSugarColumn])!, timestamp: Double(sgvRowArray[timestampColumn])!)
                    bloodSugarArray.insert(bloodSugar, at: 0)
                }
            }
            
            bloodSugarArray = self.mergeInTheNewData(oldValues: oldValues, newValues: bloodSugarArray)
            resultHandler(bloodSugarArray)
        }) 
        task.resume()
    }
    
    // append the oldvalues but leave duplicates
    fileprivate func mergeInTheNewData(oldValues : [BloodSugar], newValues : [BloodSugar]) -> [BloodSugar] {
        
        var mergedValues = oldValues
        for valueToInsert in newValues {
            
            if let index = mergedValues.index(where: { $0.timestamp > valueToInsert.timestamp }) {
                mergedValues.insert(valueToInsert, at: index)
            } else {
                // the new value is later than all other values => just append
                mergedValues.append(valueToInsert)
            }
        }
        return mergedValues
    }
    
    // appends the new value after the first value, which time is before the timestamp of newValue
    fileprivate func appendSingleValue(oldValues : [BloodSugar], newValue : BloodSugar) -> [BloodSugar] {
        
        if oldValues.count == 0 {
            return [newValue]
        }
        
        let reversedOldValues = Array(oldValues.reversed())
        var mergedValues = oldValues
        for (index, mergeValue) in reversedOldValues.enumerated() {
            if (mergeValue.timestamp < newValue.timestamp) {
                mergedValues.insert(newValue, at: index)
                return mergedValues
            }
        }
        
        return mergedValues
    }
    
    fileprivate func isDateColumn(_ cell : String) -> Bool {
        return cell.contains("-")
    }
    
    /* Reads all values from the day before. This is used for comparison with the current values. */
    func readYesterdaysChartData(_ resultHandler : @escaping (([BloodSugar]) -> Void)) {
        
        let calendar = Calendar.current
        let yesterday = TimeService.getYesterday()
        
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        let endOfYesterday = calendar.startOfDay(for: TimeService.getToday())
        
        readChartDataWithinPeriodOfTime(oldValues: [], startOfYesterday, timestamp2: endOfYesterday, resultHandler: resultHandler)
    }
    
    /* Reads all values from the current day. Beginning is 00:00 or
       the lastReceivedTime if this time is later than the current day at 00:00. */
    func readTodaysChartData(oldValues : [BloodSugar], _ resultHandler : @escaping (([BloodSugar]) -> Void)) {
        
        let calendar = Calendar.current
        let today = TimeService.getToday()
        
        var beginOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.startOfDay(for: TimeService.getTomorrow())
        
        // use the current time so that we have to load the new values only
        let lastReceivedTime = determineTheLatestValueOf(oldValues: oldValues)
        if lastReceivedTime > beginOfDay {
            beginOfDay = lastReceivedTime
        }
        readChartDataWithinPeriodOfTime(oldValues : oldValues, beginOfDay, timestamp2: endOfDay, resultHandler: resultHandler)
    }
    
    fileprivate func determineTheLatestValueOf(oldValues : [BloodSugar]) -> Date {
        if oldValues.count == 0 || oldValues.last == nil {
            return Date.init(timeIntervalSince1970: 0)
        }
        
        return Date.init(timeIntervalSince1970: oldValues.first!.timestamp / 1000)
    }
    
    func readDay(_ nrOfDaysAgo : Int, callbackHandler : @escaping (_ nrOfDay : Int, [BloodSugar]) -> Void) {
        let timeNrOfDaysAgo = TimeService.getNrOfDaysAgo(nrOfDaysAgo)
        
        let calendar = Calendar.current
        let startNrOfDaysAgo = calendar.startOfDay(for: timeNrOfDaysAgo)
        let endNrOfDaysAgo = startNrOfDaysAgo.addingTimeInterval(24 * 60 * 60)
        
        readChartDataWithinPeriodOfTime(oldValues: [], startNrOfDaysAgo, timestamp2: endNrOfDaysAgo, resultHandler: {(bgValues) -> Void in
            callbackHandler(nrOfDaysAgo, bgValues)
        })
    }
    
    /* Reads all values from the last 2 Hours before. */
    func readLastTwoHoursChartData(_ resultHandler : @escaping (([BloodSugar]) -> Void)) {
        
        let today = TimeService.getToday()
        let twoHoursBefore = today.addingTimeInterval(-60*120)
        
        readChartDataWithinPeriodOfTime(oldValues : [], twoHoursBefore, timestamp2: today, resultHandler: resultHandler)
    }
    
    /* Reads the current blood glucose data that was planned to be displayed on a pebble watch. */
    func readCurrentDataForPebbleWatch(_ resultHandler : @escaping ((NightscoutData) -> Void)) {

        let baseUri = UserDefaultsRepository.readBaseUri()
        if (baseUri == "") {
            return
        }
        
        // Get the current data from REST-Call
        let request : URLRequest = URLRequest(url: URL(string: baseUri + "/pebble")!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                return
            }

            guard data != nil else {
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
                guard let jsonDict :NSDictionary = json as? NSDictionary else {
                    return
                }
                let bgs : NSArray = jsonDict.object(forKey: "bgs") as! NSArray
                if (bgs.count > 0) {
                    let currentBgs : NSDictionary = bgs.object(at: 0) as! NSDictionary
                    
                    let sgv : NSString = currentBgs.object(forKey: "sgv") as! NSString
                    let bgdelta = Float(String(describing: currentBgs.object(forKey: "bgdelta")!))
                    let time = currentBgs.object(forKey: "datetime") as! NSNumber
                    
                    let nightscoutData = NightscoutData()
                    let battery : NSString? = currentBgs.object(forKey: "battery") as? NSString
                    
                    //Get Insulin On Board from Nightscout
                    let iob : NSString? = currentBgs.object(forKey: "iob") as? NSString
                    
                    //Define a variable to hold what will be displayed in the app (battery and iob)
                    var batteryIobDisplay : String = ""
                    
                    //If user has battery data in nightscout then add it to what's going to be displayed
                    if battery != nil {
                        batteryIobDisplay = batteryIobDisplay + String(battery!) + "%"
                    }
                    
                    //If user has battery data and iob in nightscout then add a separator between the two
                    if battery != nil && iob != nil {
                        batteryIobDisplay = batteryIobDisplay + " / "
                    }
                    
                    //If user has iob data in nightscout then add it to what's going to be displayed
                    if iob != nil {
                        batteryIobDisplay = batteryIobDisplay + String(iob!) + "U"
                    }
                    
                    if battery == nil {
                        nightscoutData.battery = String("?")
                    } else {
                        nightscoutData.battery = String(battery!) + "%"
                    }
                    
                    //Save iob data
                    if iob != nil {
                        nightscoutData.iob = String(iob!)
                    }
                    
                    //Save display data
                    nightscoutData.batteryIobDisplay = batteryIobDisplay

                    nightscoutData.sgv = String(sgv)
                    nightscoutData.bgdeltaString = self.direction(bgdelta!) + String(format: "%.1f", bgdelta!)
                    nightscoutData.bgdeltaArrow = self.getDirectionCharacter(currentBgs.object(forKey: "trend") as! NSNumber)
                    nightscoutData.bgdelta = bgdelta!
                    nightscoutData.time = time
                
                    resultHandler(nightscoutData)
                }
            } catch {
                return
            }
        }) ;
        task.resume()
    }
    
    // Converts the pebbles direction number to unicode arrow characters
    fileprivate func getDirectionCharacter(_ directionNumber : NSNumber) -> String {
        
        return DIRECTIONS[directionNumber.intValue]
    }
    
    fileprivate func direction(_ delta : Float) -> String {
        if (delta >= 0) {
            return "+"
        }
        return ""
    }
    
    fileprivate func formatTime(_ secondsSince01011970 : NSNumber) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dateString : String = timeFormatter.string(from: Date(timeIntervalSince1970: secondsSince01011970.doubleValue / 1000))
        return dateString
    }
}
