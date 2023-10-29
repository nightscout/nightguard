//
//  ServiceBoundary.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 26.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation

/* Generic Nightscout request result */
enum NightscoutRequestResult<T> {
    case data(T)
    case error(Error)
}

/* All data that is read from nightscout is accessed using this boundary. */
class NightscoutService {
    
    static let singleton = NightscoutService()
    
    let ONE_DAY_IN_MICROSECONDS = Double(60*60*24*1000)
    let DIRECTIONS = ["-", "↑↑", "↑", "↗", "→", "↘︎", "↓", "↓↓", "-", "-"]
    
    enum EventType : String {
        case sensorStart = "Sensor Change"
        case pumpBatteryChange = "Pump Battery Change"
        case cannulaChange = "Site Change"
        case temporaryTarget = "Temporary Target"
    }
    
    /* Reads the last 20 historic blood glucose data from the nightscout server. */
    @discardableResult
    func readChartData(_ resultHandler : @escaping (NightscoutRequestResult<[Int]>) -> Void) -> URLSessionTask? {
        
        // Get the current data from REST-Call
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/entries.json", queryParams: ["count": "20"])
        guard url != nil else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }
        
        let request = URLRequest(url: url!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20) as URLRequest
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            dispatchOnMain { [unowned self] in
                guard error == nil else {
                    resultHandler(.error(error!))
                    return
                }
                
                guard data != nil else {
                    resultHandler(.error(self.createNoDataError(description: NSLocalizedString("No data received from Nightscout entries API", comment: "No data from NS entries API"))))
                    return
                }
                
                let jsonArray : [String:Any] = try!JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as! [String:Any]
                var sgvValues = [Int]()
                for (key, value) in jsonArray {
                    if key == "sqv" {
                        sgvValues.insert(value as! Int, at: 0)
                    }
                    resultHandler(.data(sgvValues))
                }
            }
        })
        
        task.resume()
        return task
    }
    
    func readChartData(_ resultHandler : @escaping ([Int]) -> Void) {
        self.readChartData { (result: NightscoutRequestResult<[Int]>)  in
            if case .data(let data) = result {
                resultHandler(data)
            }
        }
    }
    
    /* Reads the nightscout status from the backend. This is used to determine the configured
     Unit, whether it's mg/dL or mmol/l */
    @discardableResult
    func readStatus(_ resultHandler : @escaping (NightscoutRequestResult<Units>) -> Void) -> URLSessionTask? {
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/status.json", queryParams: [:])
        guard url != nil else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }
        let request = URLRequest(url: url!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            
            dispatchOnMain { [unowned self] in
                guard error == nil else {
                    resultHandler(.error(error!))
                    return
                }
                
                guard data != nil else {
                    resultHandler(.error(self.createNoDataError(description: NSLocalizedString("No data received from Nightscout status API", comment: "No data from NS status API"))))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
                    guard let jsonDict :NSDictionary = json as? NSDictionary else {
                        return
                    }
                    guard let settingsDict = jsonDict.object(forKey: "settings") as? NSDictionary else {
                        return
                    }
                    if (settingsDict.count > 0) {
                        
                        guard let unitsAsString = settingsDict.value(forKey: "units") as? String else {
                            return
                        }
                        if unitsAsString.lowercased().contains("mg") {
                            resultHandler(.data(Units.mgdl))
                        } else {
                            resultHandler(.data(Units.mmol))
                        }
                    }
                } catch let error as NSError {
                    print(error.localizedDescription)
                    resultHandler(.error(error))
                }
            }
        })
        
        task.resume()
        return task
    }
    
    func readStatus(_ resultHandler : @escaping (Units) -> Void) {
        self.readStatus { (result: NightscoutRequestResult<Units>)  in
            if case .data(let data) = result {
                resultHandler(data)
            }
        }
    }
    
    /* Reads all data between two timestamps and limits the maximum return values to 1440. */
    @discardableResult
    func readChartDataWithinPeriodOfTime(oldValues : [BloodSugar], _ timestamp1 : Date, timestamp2 : Date, resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>) -> Void) -> URLSessionTask? {
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }
        
        let unixTimestamp1 : Double = timestamp1.timeIntervalSince1970 * 1000
        let unixTimestamp2 : Double = timestamp2.timeIntervalSince1970 * 1000
        
        // Get the current data from REST-Call
        let chartDataWithinPeriodOfTimeQueryParams = [
            "find[date][$gt]"   : "\(unixTimestamp1)",
            "find[date][$lte]"  : "\(unixTimestamp2)",
            "count"             : "1440",
        ]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/entries.json", queryParams: chartDataWithinPeriodOfTimeQueryParams)
        guard url != nil else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }
        
        let request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(.error(error!))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    dispatchOnMain {
                        resultHandler(
                            .error(self.createUnauthorizedError(description:
                                NSLocalizedString("You don't have write access to your nightscout site.\nDid you enter a security token in your nightscout base URI?", comment: "Error hint in case of a http 401 Exception"))))
                    }
                    return
                }
            }
            
            do {
                guard data != nil else {
                    print("The received data was nil...")
                    dispatchOnMain { [unowned self] in
                        resultHandler(.error(self.createNoDataError(description: NSLocalizedString("No data received from Nightscout entries API", comment: "No data from NS entries API"))))
                    }
                    return
                }
                
                let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
                guard let bgs = json as? NSArray else {
                    let error = NSError(domain: "Entries JSON Error", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid JSON received from Entries V2 API", comment: "Invalid JSON from Entries V2 API")])
                    dispatchOnMain {
                        resultHandler(.error(error))
                    }
                    return
                }
                
                var bloodSugarArray = [BloodSugar]()
                for singleBgValue in bgs {
                    
                    if let bgDict = singleBgValue as? Dictionary<String, Any> {
                        if let bloodValue = bgDict["sgv"] as? Double {
                            if let bloodValueTimestamp = bgDict["date"] as? Double {
                                let bloodSugar = BloodSugar(
                                        value: Float(bloodValue),
                                        timestamp: bloodValueTimestamp,
                                        isMeteredBloodGlucoseValue: false)
                                bloodSugarArray.insert(bloodSugar, at: 0)
                            }
                        }
                        if let bloodValue = bgDict["mbg"] as? Double {
                            if let bloodValueTimestamp = bgDict["date"] as? Double {
                                let bloodSugar = BloodSugar(
                                        value: Float(bloodValue),
                                        timestamp: bloodValueTimestamp,
                                        isMeteredBloodGlucoseValue: true)
                                bloodSugarArray.insert(bloodSugar, at: 0)
                            }
                        }
                    }
                }
                
                bloodSugarArray = self.mergeInTheNewData(oldValues: oldValues, newValues: bloodSugarArray)
                dispatchOnMain {
                    resultHandler(.data(bloodSugarArray))
                }
            } catch {
                print("Catched unknown exception.")
                let error = NSError(domain: "PebbleWatchDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Unknown error while extracting data from Pebble Watch API", comment: "Unkown error while extracting Pebble API data")])
                
                dispatchOnMain {
                    resultHandler(.error(error))
                }
                return
            }
        })
        
        task.resume()
        return task
    }
    
    // append the oldvalues but leave duplicates
    fileprivate func mergeInTheNewData(oldValues : [BloodSugar], newValues : [BloodSugar]) -> [BloodSugar] {
        
        var mergedValues = oldValues
        for valueToInsert in newValues {
            
            if let index = mergedValues.firstIndex(where: { $0.timestamp > valueToInsert.timestamp }) {
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
    @discardableResult
    func readYesterdaysChartData(_ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>) -> Void) -> URLSessionTask? {
        
        let calendar = Calendar.current
        let yesterday = TimeService.getYesterday()
        
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        let endOfYesterday = calendar.startOfDay(for: TimeService.getToday())
        
        return readChartDataWithinPeriodOfTime(oldValues: [], startOfYesterday, timestamp2: endOfYesterday, resultHandler: resultHandler)
    }
    
    func readYesterdaysChartData(_ resultHandler : @escaping ([BloodSugar]) -> Void) {
        
        self.readYesterdaysChartData { (result: NightscoutRequestResult<[BloodSugar]>)  in
            if case .data(let data) = result {
                resultHandler(data)
            }
        }
    }
    
    /* Reads all values from the current day. Beginning is 00:00 or
     the lastReceivedTime if this time is later than the current day at 00:00. */
    @discardableResult
    func readTodaysChartData(oldValues : [BloodSugar], _ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>) -> Void) -> URLSessionTask? {
        
        let calendar = Calendar.current
        let today = TimeService.getToday()
        
        var beginOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.startOfDay(for: TimeService.getTomorrow())
        
        // use the current time so that we have to load the new values only
        let lastReceivedTime = determineTheLatestValueOf(oldValues: oldValues)
        if lastReceivedTime > beginOfDay {
            beginOfDay = lastReceivedTime
        }
        
        return readChartDataWithinPeriodOfTime(oldValues : oldValues, beginOfDay, timestamp2: endOfDay, resultHandler: resultHandler)
    }
    
    func readTodaysChartData(oldValues : [BloodSugar], _ resultHandler : @escaping ([BloodSugar]) -> Void) {
        
        self.readTodaysChartData(oldValues: oldValues) { (result: NightscoutRequestResult<[BloodSugar]>)  in
            if case .data(let data) = result {
                resultHandler(data)
            }
        }
    }
    
    fileprivate func determineTheLatestValueOf(oldValues : [BloodSugar]) -> Date {
        if oldValues.count == 0 || oldValues.last == nil {
            return Date.init(timeIntervalSince1970: 0)
        }
        
        return Date.init(timeIntervalSince1970: (oldValues.last?.timestamp ?? 0) / 1000)
    }
    
    @discardableResult
    func readDay(_ nrOfDaysAgo : Int, callbackHandler : @escaping (_ nrOfDay : Int, NightscoutRequestResult<[BloodSugar]>) -> Void) -> URLSessionTask? {
        let timeNrOfDaysAgo = TimeService.getNrOfDaysAgo(nrOfDaysAgo)
        
        let calendar = Calendar.current
        let startNrOfDaysAgo = calendar.startOfDay(for: timeNrOfDaysAgo)
        let endNrOfDaysAgo = startNrOfDaysAgo.addingTimeInterval(24 * 60 * 60)
        
        return readChartDataWithinPeriodOfTime(oldValues: [], startNrOfDaysAgo, timestamp2: endNrOfDaysAgo) { result in
            callbackHandler(nrOfDaysAgo, result)
        }
    }
    
    func readDay(_ nrOfDaysAgo : Int, callbackHandler : @escaping (_ nrOfDay : Int, [BloodSugar]) -> Void) {
        
        self.readDay(nrOfDaysAgo) { (nrOfDay: Int, result: NightscoutRequestResult<[BloodSugar]>)  in
            if case .data(let data) = result {
                callbackHandler(nrOfDay, data)
            }
        }
    }
    
    /* Reads all values from the last 2 Hours before. */
    @discardableResult
    func readLastTwoHoursChartData(_ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>) -> Void) -> URLSessionTask? {
        
        let today = TimeService.getToday()
        let twoHoursBefore = today.addingTimeInterval(-60*120)
        
        return readChartDataWithinPeriodOfTime(oldValues : [], twoHoursBefore, timestamp2: today, resultHandler: resultHandler)
    }
    
    /* Reads the current blood glucose data that was planned to be displayed on a pebble watch. */
    @discardableResult
    func readCurrentData(_ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>) -> Void) -> URLSessionTask? {
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if (baseUri == "") {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }
        
        // Get the current data from REST-Call
        // Force mgdl here, since all values are kept internall in mgdl.
        // Only for the UI, they are transformed to mmol. This enables us to let the user manually
        // switch to the wished units.
        // All other endpoints deliver in mgdl, too. So this makes sence to enforce it here, too:
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v2/properties", queryParams: [:])
        guard url != nil else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }
        var request : URLRequest = URLRequest(url: url!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.timeoutInterval = 70
        
        let session : URLSession = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print("Error receiving api/v2/properties Data.")
                print(error!)
                dispatchOnMain {
                    resultHandler(.error(error!))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    dispatchOnMain {
                        resultHandler(
                            .error(self.createUnauthorizedError(description:
                                NSLocalizedString("You don't have write access to your nightscout site.\nDid you enter a security token in your nightscout base URI?", comment: "Error hint in case of a http 401 Exception"))))
                    }
                    return
                }
            }
            
            guard data != nil else {
                print("API V2 Properties Data was nil.")
                dispatchOnMain { [unowned self] in
                    resultHandler(.error(self.createNoDataError(description: NSLocalizedString("No data received from API V2 Properties", comment: "No data received from API V2 Properties"))))
                }
                return
            }
            
            self.extractApiV2PropertiesData(data : data!, resultHandler)
        })
        
        task.resume()
        return task
    }
    
    public func extractApiV2PropertiesData(data : Data, _ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>) -> Void) {
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)
            guard let jsonDict :NSDictionary = json as? NSDictionary else {
                let error = NSError(domain: "APIV2PropertiesDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid JSON received from API V2 Properties", comment: "Invalid JSON received from API V2 Properties")])
                dispatchOnMain {
                    resultHandler(.error(error))
                }
                return
            }
            
            guard let currentBgs = jsonDict.object(forKey: "bgnow") as? NSDictionary else {
                let error = NSError(domain: "APIV2PropertiesDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid JSON received from API V2 Properties, missing bgs data. Check Nightscout configuration.", comment: "Invalid JSON from API V2 Properties, missing bgs, check NS conf")])
                dispatchOnMain {
                    resultHandler(.error(error))
                }
                return
            }
            
            if currentBgs.object(forKey: "last") == nil {
                if currentBgs.object(forKey: "errors") != nil {
                    // Looks like we have values, but these are marked as erroneous
                    // Give a hint to the user by removing the old values and
                    // displaying empty data:
                    dispatchOnMain {
                        resultHandler(.data(NightscoutData()))
                    }
                    return
                }
                // if no more glucose values can't be retrieved: backout - so that the last retrieved value is preserved
                // this is useful to see how old the last retrieved value is
                return
            }
            let sgv : NSNumber = currentBgs.object(forKey: "last") as? NSNumber ?? 0
            let time = currentBgs.object(forKey: "mills") as? NSNumber ?? 0
            
            let upbat = jsonDict.object(forKey: "upbat") as? NSDictionary ?? NSDictionary()
            let nightscoutData = NightscoutData()
            nightscoutData.battery = upbat.object(forKey: "display") as? String ?? "?"
            
            //Get Insulin On Board from Nightscout
            let iobDict = jsonDict.object(forKey: "iob") as? NSDictionary ?? NSDictionary()
            if let iob = iobDict.object(forKey: "display") as? String {
                nightscoutData.iob = String(iob) + "U"
            }
            
            //Get Carbs On Board from Nightscout
            let cobDict = jsonDict.object(forKey: "cob") as? NSDictionary ?? NSDictionary()
            if let cob : Double = cobDict.object(forKey: "display") as? Double {
                nightscoutData.cob = cob.string(fractionDigits: 0) + "g"
            }
            
            nightscoutData.sgv = String(describing: sgv)
            nightscoutData.time = time
            
            let directionDict = jsonDict.object(forKey: "direction") as? NSDictionary ?? NSDictionary()
            nightscoutData.bgdeltaArrow = directionDict.object(forKey: "label") as? String ?? "-"
            
            let deltaDict = jsonDict.object(forKey: "delta") as? NSDictionary ?? NSDictionary()
            nightscoutData.bgdeltaString = deltaDict.object(forKey: "display") as? String ?? "?"
            nightscoutData.bgdelta = deltaDict.object(forKey: "mgdl") as? Float ?? 0.0
            
            dispatchOnMain {
                resultHandler(.data(nightscoutData))
            }
            
        } catch {
            print("Catched unknown exception.")
            let error = NSError(domain: "PebbleWatchDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Unknown error while extracting data from Pebble Watch API", comment: "Unkown error while extracting Pebble API data")])
            
            dispatchOnMain {
                resultHandler(.error(error))
            }
            return
        }
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
    
    fileprivate func getNoiseLevel(_ noiseCode : Int, sgv: String) -> String {
        
        // as implemented in https://github.com/nightscout/cgm-remote-monitor/blob/d407bab2096d739708f365eae3c78847291bc997/lib/plugins/rawbg.js
        switch noiseCode {
        case 0:
            return "---"
        case 1:
            return "Clean"
        case 2:
            return "Light"
        case 3:
            return "Medium"
        case 4:
            return "Heavy"
        default:
            if UnitsConverter.displayValueToMgdl(sgv) < 40.0 {
                return "Heavy"
            } else {
                return "~~~"
            }
        }
    }
    
    /* Reads the treatment record for the last cannula change, sensor change and battery age */
    @discardableResult
    func readLastTreatementEventTimestamp(eventType : EventType, daysToGoBackInTime : Int, resultHandler : @escaping (Date) -> Void) -> URLSessionTask? {
        
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler(Date())
            return nil
        }
        
        // Get the current data from REST-Call
        let daysBackInTime = Calendar.current.date(
                byAdding: .day, value: -daysToGoBackInTime, to: Date()) ?? Date()
        let lastTreatmentByEventtype = [
            "find[eventType]" : eventType.rawValue,
            // Go back 10 Days in time. That should be enough for even the Sensor Age
            "find[created_at][$gte]" :  daysBackInTime.convertToIsoDate(),
            "count" : "1"
        ]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/treatments", queryParams: lastTreatmentByEventtype)
        guard url != nil else {
            resultHandler(Date())
            return nil
        }
        
        let request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(Date())
                }
                return
            }
            
            guard data != nil else {
                print("The received data was nil...")
                dispatchOnMain { [] in
                    resultHandler(Date())
                }
                return
            }
            
            do {
                guard let treatmentsArray = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as? [Any] else {
                    print("Unexpected treatments received...")
                    dispatchOnMain { [] in
                        resultHandler(Date())
                    }
                    return
                }
            
                guard let siteChangeObject = treatmentsArray as? [[String:Any]]
                    else {
                        dispatchOnMain { [] in
                            resultHandler(Date())}
                        return
                }
                
                if siteChangeObject.count == 0 {
                    dispatchOnMain { [] in
                        resultHandler(Date())}
                    return
                }
                
                dispatchOnMain { [] in
                    guard let siteChangeUnwrapped = siteChangeObject[0]["created_at"]
                        else {
                            return
                    }
                    resultHandler(Date.fromIsoString(isoTime: String(describing: siteChangeUnwrapped)))}
            } catch {
                print("Exception catched during treatements parsing. Ignoring the result...")
                return
            }
        })
        
        task.resume()
        return task
    }
    
    func readLastTemporaryTarget(daysToGoBackInTime : Int, resultHandler : @escaping (TemporaryTargetData?) -> Void) {
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler(nil)
            return
        }
        
        // Get the current data from REST-Call
        let lastTreatmentByEventtype = [
            "find[eventType]" : "Temporary Target",
            "find[created_at][$gte]" :  Calendar.current.date(
                byAdding: .day, value: -1, to: Date())!.convertToIsoDate(),
            "count" : "1"
        ]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/treatments", queryParams: lastTreatmentByEventtype)
        guard url != nil else {
            resultHandler(nil)
            return
        }
        
        var request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        // Setting an empty body - otherwise the GET Request can lead to crazy
        // Results, because Apple is complaining about a body request isn`t allowed
        // during get requests:
        request.httpBody = nil
        request.addValue("0", forHTTPHeaderField: "Content-Length")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(nil)
                }
                return
            }
            
            guard data != nil else {
                print("The received data was nil...")
                dispatchOnMain {
                    resultHandler(nil)
                }
                return
            }
            
            do {
                let treatmentsArray = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as? [Any]
                
                guard let temporaryTargetObject = treatmentsArray as? [[String:Any]]
                    else {
                        dispatchOnMain {
                            resultHandler(nil)}
                        return
                }
                
                if temporaryTargetObject.count == 0 {
                    dispatchOnMain {
                        resultHandler(nil)}
                    return
                }
                
                dispatchOnMain {
                    
                    let temporaryTargetData = TemporaryTargetData()
                    
                    let temporaryTarget = TemporaryTarget.parse(
                        temporaryTargetDict: temporaryTargetObject[0])
                    temporaryTargetData.targetTop = temporaryTarget.targetTop
                    temporaryTargetData.targetBottom = temporaryTarget.targetBottom
                    temporaryTargetData.activeUntilDate = self.calculateEndDate(
                        createdAt: temporaryTarget.createdAt, durationInMinutes: temporaryTarget.duration)
                    
                    resultHandler(temporaryTargetData)
                }
            } catch {
                print("Exception during reading of the temporary target. Ignoring the result...")
            }
        })
        
        task.resume()
    }
    
    func createTemporaryTarget(reason: String, target: Int, durationInMinutes: Int, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler("The base URI is empty!")
            return
        }
        
        // Get the current data from REST-Call
        let createTemporaryTargetParameter = [
            "now" : String(describing: Date.timeIntervalSince(Date()))]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/treatments", queryParams: createTemporaryTargetParameter)
        guard url != nil else {
            resultHandler("The url was nil. This should never happen!")
            return
        }
        
        var request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let json =
        """
        {"eventType": "Temporary Target",
        "duration": \(durationInMinutes),
        "reason": "\(reason)\",
        "targetBottom": \(target),
        "targetTop": \(target),
        "units": "mg/dl",
        "enteredBy": "nightguard"}
        """
        request.httpBody = json.data(using: .utf8, allowLossyConversion: false)!
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(error?.localizedDescription)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    dispatchOnMain {
                        resultHandler(
                            NSLocalizedString("You don't have write access to your nightscout site.\nDid you enter a security token in your nightscout base URI?", comment: "Error hint in case of a http 401 Exception"))
                    }
                    return
                }
            }
            
            dispatchOnMain {
                resultHandler(nil)
            }
        })
        
        task.resume()
    }
    
    /* Deleting works by setting a temporary target with duration 0 */
    func deleteTemporaryTarget(resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler("The base URI is empty!")
            return
        }
        
        // Get the current data from REST-Call
        let createTemporaryTargetParameter = [
            "now" : String(describing: Date.timeIntervalSince(Date()))]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/treatments", queryParams: createTemporaryTargetParameter)
        guard url != nil else {
            resultHandler("The url was nil. This should never happen!")
            return
        }
        
        var request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let json =
        """
            {"eventType": "Temporary Target",
            "duration": 0,
            "reason": "Canceled",
            "enteredBy": "nightguard"}
        """
        request.httpBody = json.data(using: .utf8, allowLossyConversion: false)!
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(error?.localizedDescription)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    dispatchOnMain {
                        resultHandler(
                            NSLocalizedString("You don't have write access to your nightscout site.\nDid you enter a security token in your nightscout base URI?", comment: "Error hint in case of a http 401 Exception"))
                    }
                    return
                }
            }
            
            dispatchOnMain { [] in
                resultHandler(nil)
            }
        })
        
        task.resume()
    }
    
    private func calculateEndDate(createdAt : String?, durationInMinutes : Int?) -> Date {
        
        if let createdAt = createdAt, let durationInMinutes = durationInMinutes {
            let creationDate = Date.fromIsoString(isoTime: createdAt)
            return Calendar.current.date(byAdding: .minute, value: durationInMinutes, to: creationDate) ?? Date()
        }
        
        return Date()
    }
    
    func createCarbsCorrection(carbs: Int, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler("The base URI is empty!")
            return
        }
        
        // Get the current data from REST-Call
        let queryParameter = [
            "now" : String(describing: Date.timeIntervalSince(Date()))]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/treatments", queryParams: queryParameter)
        guard url != nil else {
            resultHandler("The url was nil. This should never happen!")
            return
        }
        
        var request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let json =
        """
        {"eventType": "Carb Correction",
        "carbs": \(carbs),
        "duration": 0,
        "enteredBy": "nightguard"}
        """
        request.httpBody = json.data(using: .utf8, allowLossyConversion: false)!
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(error?.localizedDescription)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    dispatchOnMain {
                        resultHandler(
                            NSLocalizedString("You don't have write access to your nightscout site.\nDid you enter a security token in your nightscout base URI?", comment: "Error hint in case of a http 401 Exception"))
                    }
                    return
                }
            }
            
            dispatchOnMain {
                resultHandler(nil)
            }
        })
        
        task.resume()
    }
    
    func createCannulaChangeTreatment(changeDate: Date, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler("The base URI is empty!")
            return
        }
        
        // Get the current data from REST-Call
        let queryParameter = [
            "now" : String(describing: Date.timeIntervalSince(Date()))]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/treatments", queryParams: queryParameter)
        guard url != nil else {
            resultHandler("The url was nil. This should never happen!")
            return
        }
        
        var request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let json =
        """
            {"eventType": "\(EventType.cannulaChange.rawValue)",
            "enteredBy": "nightguard",
            "created_at": "\(changeDate.convertToIsoDateTime())",
            "mills":\(changeDate.toUTCMillis()),
            "notes": "",
            "carbs":null,
            "insulin":null}
        """
        request.httpBody = json.data(using: .utf8, allowLossyConversion: false)!
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(error?.localizedDescription)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    dispatchOnMain {
                        resultHandler(
                            NSLocalizedString("You don't have write access to your nightscout site.\nDid you enter a security token in your nightscout base URI?", comment: "Error hint in case of a http 401 Exception"))
                    }
                    return
                }
            }
            
            dispatchOnMain {
                resultHandler(nil)
            }
        })
        
        task.resume()
    }
    
    func createSensorChangeTreatment(changeDate: Date, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler("The base URI is empty!")
            return
        }
        
        // Get the current data from REST-Call
        let queryParameter = [
            "now" : String(describing: Date.timeIntervalSince(Date()))]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/treatments", queryParams: queryParameter)
        guard url != nil else {
            resultHandler("The url was nil. This should never happen!")
            return
        }
        
        var request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let json =
        """
            {"eventType": "\(EventType.sensorStart.rawValue)",
            "enteredBy": "nightguard",
            "created_at": "\(changeDate.convertToIsoDateTime())",
            "mills":\(changeDate.toUTCMillis()),
            "notes": "",
            "carbs":null,
            "insulin":null}
        """
        request.httpBody = json.data(using: .utf8, allowLossyConversion: false)!
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(error?.localizedDescription)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    dispatchOnMain {
                        resultHandler(
                            NSLocalizedString("You don't have write access to your nightscout site.\nDid you enter a security token in your nightscout base URI?", comment: "Error hint in case of a http 401 Exception"))
                    }
                    return
                }
            }
            
            dispatchOnMain {
                resultHandler(nil)
            }
        })
        
        task.resume()
    }
    
    func createBatteryChangeTreatment(changeDate: Date, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler("The base URI is empty!")
            return
        }
        
        // Get the current data from REST-Call
        let queryParameter = [
            "now" : String(describing: Date.timeIntervalSince(Date()))]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/treatments", queryParams: queryParameter)
        guard url != nil else {
            resultHandler("The url was nil. This should never happen!")
            return
        }
        
        var request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let json =
        """
            {"eventType": "\(EventType.pumpBatteryChange.rawValue)",
            "enteredBy": "nightguard",
            "created_at": "\(changeDate.convertToIsoDateTime())",
            "mills":\(changeDate.toUTCMillis()),
            "notes": "",
            "carbs":null,
            "insulin":null}
        """
        request.httpBody = json.data(using: .utf8, allowLossyConversion: false)!
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(error?.localizedDescription)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    dispatchOnMain {
                        resultHandler(
                            NSLocalizedString("You don't have write access to your nightscout site.\nDid you enter a security token in your nightscout base URI?", comment: "Error hint in case of a http 401 Exception"))
                    }
                    return
                }
            }
            
            dispatchOnMain {
                resultHandler(nil)
            }
        })
        
        task.resume()
    }
    
    /* Reads the devicestatus to get pump basal rate and profile */
    @discardableResult
    func readDeviceStatus(resultHandler : @escaping (DeviceStatusData) -> Void) -> URLSessionTask? {
        
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler(DeviceStatusData())
            return nil
        }
        
        // We assume that the last 5 entries should contain the entry with the extended pump entries
        let lastTwoDeviceStatusQuery = [
            "count" : "5"
        ]
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/devicestatus.json", queryParams: lastTwoDeviceStatusQuery)
        guard url != nil else {
            resultHandler(DeviceStatusData())
            return nil
        }
        
        let request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler(DeviceStatusData())
                }
                return
            }
            
            guard data != nil else {
                print("The received data was nil...")
                dispatchOnMain {
                    resultHandler(DeviceStatusData())
                }
                return
            }
            
            do {
                let deviceStatusRawArray = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as? [Any]
                
                guard let deviceStatusArray = deviceStatusRawArray as? [[String:Any]]
                    else {
                        dispatchOnMain { [] in
                            resultHandler(DeviceStatusData())}
                        return
                }
                
                for deviceStatus in deviceStatusArray {
                    // only the pump device status are interesting here
                    if deviceStatus.contains(where: {$0.key == "pump"}) {
                        guard let pumpEntries = deviceStatus["pump"] as? [String:Any]
                            else {
                                dispatchOnMain { [] in
                                    resultHandler(DeviceStatusData())}
                                return
                        }
                        var reservoirUnits = 0
                        if let reservoirUnitsProbe = pumpEntries["reservoir"] as? Double {
                            reservoirUnits = Int(reservoirUnitsProbe)
                        }
                        if pumpEntries.contains(where: {$0.key == "extended"}) {
                            guard let extendedEntries = pumpEntries["extended"] as? [String:Any]
                                else {
                                    dispatchOnMain { [] in
                                        resultHandler(DeviceStatusData())}
                                    return
                            }
                            if extendedEntries.contains(where: {$0.key == "ActiveProfile"}) {
                                dispatchOnMain { [] in
                                    
                                    let deviceStatusData = DeviceStatusData(
                                        activePumpProfile: extendedEntries["ActiveProfile"] as! String,
                                        //TODO: Implement and use the AAPS timestamp here
                                        pumpProfileActiveUntil: nil,
                                        reservoirUnits: reservoirUnits,
                                        temporaryBasalRate:
                                        self.calculateTempBasalPercentage(
                                            baseBasalRate: extendedEntries["BaseBasalRate"],
                                            tempBasalAbsoluteRate: extendedEntries["TempBasalAbsoluteRate"]),
                                        temporaryBasalRateActiveUntil:
                                        self.calculateTempBasalEndTime(
                                            tempBasalRemainingMinutes: extendedEntries["TempBasalRemaining"]))
                                    
                                    resultHandler(deviceStatusData)}
                                return
                            }
                        } else {
                            // no extended data => just return the reservoir units
                            dispatchOnMain { [] in
                                let deviceStatusData = DeviceStatusData(
                                    activePumpProfile: "---",
                                    //TODO: Implement and use the AAPS timestamp here
                                    pumpProfileActiveUntil: nil,
                                    reservoirUnits: reservoirUnits,
                                    temporaryBasalRate: "--",
                                    temporaryBasalRateActiveUntil: Date())
                                
                                    resultHandler(deviceStatusData)}
                            return
                        }
                    }
                }
            } catch {
                print("Exception reading device status. Ignoring the result.")
                return
            }
            
            // if no pump entry exists - return nothing
            dispatchOnMain { [] in
                resultHandler(DeviceStatusData())}
            return
        })
        
        task.resume()
        return task
    }
    
    // Simply read the latest Treatements without giving any more informations.
    // This is preferred on the nightscout backend, because this result can be efficiently cache
    // and updated on the server side.
    
    // So we are switching to this simply way in nightguard...
    @discardableResult
    func readLatestTreatements(resultHandler : @escaping ([[String:Any]]) -> Void) -> URLSessionTask? {
        
        
        let baseUri = UserDefaultsRepository.baseUri.value
        if baseUri == "" {
            resultHandler([])
            return nil
        }
        
        let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v1/treatments.json", queryParams: [String : String]())
        guard url != nil else {
            resultHandler([])
            return nil
        }
        
        let request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            guard error == nil else {
                print(error!)
                dispatchOnMain {
                    resultHandler([])
                }
                return
            }
            
            guard data != nil else {
                print("The received data was nil...")
                dispatchOnMain { [] in
                    resultHandler([])
                }
                return
            }
            
            do {
                guard let treatmentsArray = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as? [Any] else {
                    print("Unexpected treatments received...")
                    dispatchOnMain { [] in
                        resultHandler([])
                    }
                    return
                }
            
                guard let treatments = treatmentsArray as? [[String:Any]]
                    else {
                        dispatchOnMain { [] in
                            resultHandler([])}
                        return
                }
                
                dispatchOnMain { [] in
                    resultHandler(treatments)}
            } catch {
                print("Exception catched during treatements parsing. Ignoring the result...")
                return
            }
        })
        
        task.resume()
        return task
    }
    
    
    private func calculateTempBasalPercentage(baseBasalRate: Any?, tempBasalAbsoluteRate: Any?) -> String {
        
        guard let baseBasalRateAsDouble = Double.fromAny(baseBasalRate as Any) else {
            return ""
        }
        if (tempBasalAbsoluteRate == nil) {
            return ""
        }
        guard let tempBasalAbsoluteRateAsDouble = Double.fromAny(tempBasalAbsoluteRate as Any) else {
            return ""
        }
        
        return Double(tempBasalAbsoluteRateAsDouble / baseBasalRateAsDouble * 100).rounded().string(fractionDigits: 0)
    }
    
    private func calculateTempBasalEndTime(tempBasalRemainingMinutes: Any?) -> Date {
        
        if let tempBasalRemainingMinutesAsInt = tempBasalRemainingMinutes as? Int {
            
            return Calendar.current.date(byAdding: .minute, value: tempBasalRemainingMinutesAsInt, to: Date()) ?? Date()
        }
        return Date()
    }
    
    private func createEmptyOrInvalidUriError() -> Error {
        return NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo:  [NSLocalizedDescriptionKey: NSLocalizedString("The base URI is empty or invalid!", comment: "Empty or invalid Uri error")])
    }
    
    private func createNoDataError(description: String ) -> Error {
        return NSError(domain: "NightguardError", code: -1, userInfo: [NSLocalizedDescriptionKey: description])
    }
    
    private func createUnauthorizedError(description: String ) -> Error {
        return NSError(domain: "NightguardError", code: -1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
