//
//  ComplicationController.swift
//  scoutwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import ClockKit
import WatchKit

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    var oldNightscoutData : [NightscoutData] = []
    
    /*
    func getNextRequestedUpdateDate(handler: @escaping (Date?) -> Void) {
        // Update every 10 Minutes => but this is just a nice wish
        // => Apple will allow maybe just 30 minutes :(
        handler(Date(timeIntervalSinceNow: 60*10))
    }*/
    
    // MARK: - Timeline Configuration
    
    // No Timetravel supported
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        
        let currentNightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        eventuallyAddToOldNightscoutData(newNightscoutData: currentNightscoutData)
        
        var template : CLKComplicationTemplate? = nil
            
        switch complication.family {
        case .modularSmall:
            let modTemplate = CLKComplicationTemplateModularSmallStackText()
            modTemplate.line1TextProvider = CLKSimpleTextProvider(text: getSgvAndArrow(currentNightscoutData))
            modTemplate.line2TextProvider = getRelativeDateTextProvider(for: currentNightscoutData.time)
            template = modTemplate
        case .modularLarge:
            let modTemplate = CLKComplicationTemplateModularLargeColumns()
            
            modTemplate.row1Column1TextProvider = CLKSimpleTextProvider(text: getOneLine(currentNightscoutData))
            modTemplate.row1Column2TextProvider = getRelativeDateTextProvider(for: currentNightscoutData.time)
            modTemplate.row2Column1TextProvider = CLKSimpleTextProvider(text: "")
            modTemplate.row2Column2TextProvider = CLKSimpleTextProvider(text: "")
            modTemplate.row3Column1TextProvider = CLKSimpleTextProvider(text: "")
            modTemplate.row3Column2TextProvider = CLKSimpleTextProvider(text: "")
            if self.oldNightscoutData.count > 1 {
                let nightscoutData = self.oldNightscoutData[1]
                modTemplate.row2Column1TextProvider = CLKSimpleTextProvider(text: getOneLine(nightscoutData))
                modTemplate.row2Column2TextProvider = getRelativeDateTextProvider(for: nightscoutData.time)
            }
            if self.oldNightscoutData.count > 2 {
                let nightscoutData = self.oldNightscoutData[2]
                modTemplate.row3Column1TextProvider = CLKSimpleTextProvider(text: getOneLine(nightscoutData))
                modTemplate.row3Column2TextProvider = getRelativeDateTextProvider(for: nightscoutData.time)
            }
            
            template = modTemplate
        case .utilitarianSmall:
            let modTemplate = CLKComplicationTemplateUtilitarianSmallFlat()
            modTemplate.textProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
            template = modTemplate
        case .utilitarianLarge:
            let modTemplate = CLKComplicationTemplateUtilitarianLargeFlat()
            modTemplate.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Complication/Circular")!)
            modTemplate.textProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
            template = modTemplate
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallRingText()
            template.textProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.sgv)")
            
            template.fillFraction = self.getAgeOfDataInMinutes(currentNightscoutData.time) / 60
            template.ringStyle = CLKComplicationRingStyle.closed
        default: break
        }
        
        if template != nil {
            let timelineEntry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template!)
            handler(timelineEntry)
        }
    }
    
    // if new data was received => put it to the list of old data
    fileprivate func eventuallyAddToOldNightscoutData(newNightscoutData : NightscoutData) {
        
        if oldNightscoutData.count == 0 || newNightscoutData.time != oldNightscoutData[0].time {
            oldNightscoutData.insert(newNightscoutData, at: 0)
            
            removeDummyNightscoutData()
        }
    }
    
    // Removes the dummy entry "??:??" which has been appended if no data was available at all
    fileprivate func removeDummyNightscoutData() {
        
        oldNightscoutData = oldNightscoutData.filter{!$0.hourAndMinutes.contains("?")}
    }
    
    // Display 11:24 113+2
    func getOneBigLine(_ data : NightscoutData) -> String {
        return "\(data.hourAndMinutes) \(data.sgv)\(data.bgdeltaString.cleanFloatValue)\(data.bgdeltaArrow)"
    }
    
    // Displays 113 ↗ (+2)
    func getOneLine(_ data : NightscoutData) -> String {
        return "\(getSgvAndArrow(data))\t\(data.bgdeltaString.cleanFloatValue)"
    }
    
    func getSgvAndArrow(_ data: NightscoutData) -> String {
        let separator = data.bgdeltaArrow.count > 1 ? "" : " "
        return [data.sgv, data.bgdeltaArrow].joined(separator: separator)
    }
    
    // If the age is older than 59 minutes => return 60 in that case
    func getAgeOfDataInMinutes(_ time : NSNumber) -> Float {
        
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        let difference = (currentTime - time.int64Value) / 60000
        if difference > 59 {
            return 60
        }
        return Float(difference)
    }
    
    func getRelativeDateTextProvider(for time: NSNumber) -> CLKTextProvider {
        
        guard time.doubleValue > 0 else {
            return CLKSimpleTextProvider(text: "???")
        }
        
        let date: Date = Date(timeIntervalSince1970: time.doubleValue / 1000)
        
        // trick: we'll adjust the time with one minute to keep the complication relative time in sync with the minutes shown in the app
        let calendar = Calendar.current
        let adjustedDate = calendar.date(byAdding: .minute, value: 1, to: date)!
        
        let isOlderThanTwoHours = getAgeOfDataInMinutes(time) >= 120
        return CLKRelativeDateTextProvider(date: adjustedDate, style: .natural, units: isOlderThanTwoHours ? .hour : .minute)
    }
    
    // MARK: - Placeholder Templates
    
    func getPlaceholderTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        var template: CLKComplicationTemplate? = nil
        switch complication.family {
        case .modularSmall:
            template = nil
        case .modularLarge:
            template = nil
        case .utilitarianSmall:
            template = nil
        case .utilitarianLarge:
            template = nil
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallRingImage()
            template.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Complication/Circular")!)
        default: break
        }
        handler(template)
    }
    
}
