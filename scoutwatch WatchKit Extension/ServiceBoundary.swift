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

    /* Reads the current blood glucose data that was planned to be displayed on a pebble watch. */
    func readCurrentDataForPebbleWatch(resultHandler : (BgData -> Void)) {
        
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
            
            let json = try!NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)
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
                
                let bgData = BgData()
                bgData.sgv = String(sgv)
                bgData.bgdeltaString = self.direction(bgdelta) + String(bgdelta)
                bgData.bgdelta = bgdelta
                bgData.time = time
                bgData.battery = String(battery) + "%"
                
                resultHandler(bgData)
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