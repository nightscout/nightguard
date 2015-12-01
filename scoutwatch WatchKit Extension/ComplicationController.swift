//
//  ComplicationController.swift
//  scoutwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import ClockKit


class ComplicationController: NSObject, CLKComplicationDataSource {
    
    var currentTimeline1Text : String = "---"
    var currentTimeline2Text : String = "--:--"
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirectionsForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.None])
    }
    
    func getTimelineStartDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        handler(nil)
    }
    
    func getTimelineEndDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        handler(nil)
    }
    
    func getPrivacyBehaviorForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.ShowOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntryForComplication(complication: CLKComplication, withHandler handler: ((CLKComplicationTimelineEntry?) -> Void)) {
        if complication.family == .CircularSmall {
            createData()
            let template = CLKComplicationTemplateCircularSmallStackText()
            
            template.line1TextProvider = CLKSimpleTextProvider(text: currentTimeline1Text)
            template.line2TextProvider = CLKSimpleTextProvider(text: currentTimeline2Text)
            let timelineEntry = CLKComplicationTimelineEntry(date: NSDate(), complicationTemplate: template)
            handler(timelineEntry)
        } else {
            handler(nil)
        }
    }
    
    func createData() {
        // Get the current data from REST-Call
        let request : NSMutableURLRequest = NSMutableURLRequest(URL: NSURL(string: "https://dhe.my-wan.de/pebble")!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 20)
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
                let delta = currentBgs.objectForKey("bgdelta") as! NSNumber
                let datetime = currentBgs.objectForKey("datetime") as! NSNumber
                
                self.currentTimeline1Text = self.createLine1(sgv, delta: delta)
                self.currentTimeline2Text = self.createLine2(datetime)
            }
            
        };
        task.resume()
    }
    
    func createLine1(sgv : NSString, delta : NSNumber) -> String {
        if (delta.intValue > 9) {
            return (sgv as String) + "++"
        }
        if (delta.intValue > 0) {
            return (sgv as String) + "+" + String(delta);
        } else if (delta.intValue < 0) {
            return (sgv as String) + "-" + String(delta);
        } else {
            return sgv as String
        }
    }
    
    func createLine2(datetime : NSNumber) -> String {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let dateString : String = dateFormatter.stringFromDate(NSDate(timeIntervalSince1970: datetime.doubleValue))
        return dateString
    }
    
    func getTimelineEntriesForComplication(complication: CLKComplication, beforeDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }
    
    func getTimelineEntriesForComplication(complication: CLKComplication, afterDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        handler(nil)
    }
    
    // MARK: - Update Scheduling
    
    func getNextRequestedUpdateDateWithHandler(handler: (NSDate?) -> Void) {
        // Update every 5 Minutes
        handler(NSDate(timeIntervalSinceNow: 30))
    }
    
    func requestedUpdateDidBegin() {
        print("Complication update is starting")
        
        createData()
        
        let server=CLKComplicationServer.sharedInstance()
        
        for comp in (server.activeComplications) {
            server.reloadTimelineForComplication(comp)
            print("Timeline has been reloaded!")
        }
        
    }
    
    func requestedUpdateBudgetExhausted() {
        print("Budget exhausted")
    }
    
    // MARK: - Placeholder Templates
    
    func getPlaceholderTemplateForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> Void) {
        var template: CLKComplicationTemplate? = nil
        switch complication.family {
        case .ModularSmall:
            template = nil
        case .ModularLarge:
            template = nil
        case .UtilitarianSmall:
            template = nil
        case .UtilitarianLarge:
            template = nil
        case .CircularSmall:
            let template = CLKComplicationTemplateCircularSmallStackText()
            template.line1TextProvider = CLKSimpleTextProvider(text: currentTimeline1Text)
            template.line2TextProvider = CLKSimpleTextProvider(text: currentTimeline2Text)
        }
        handler(template)
    }
    
}
