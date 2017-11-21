//
//  ComplicationController.swift
//  scoutwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import ClockKit


class ComplicationController: NSObject, CLKComplicationDataSource {
    
    var oldNightscoutData : [NightscoutData] = []
    
    func getNextRequestedUpdateDate(handler: @escaping (Date?) -> Void) {
        // Update every 15 Minutes => but this is just a nice wish
        // => Apple will allow maybe just 30 minutes :(
        handler(Date(timeIntervalSinceNow: 60*15))
    }
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler(CLKComplicationTimeTravelDirections())
    }
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        
        let currentNightscoutData = NightscoutCacheService.singleton.getCurrentNightscoutData()
        eventuallyAddToOldNightscoutData(newNightscoutData: currentNightscoutData)
        
        var template : CLKComplicationTemplate? = nil
            
        switch complication.family {
        case .modularSmall:
            let modTemplate = CLKComplicationTemplateModularSmallStackText()
            
            modTemplate.line1TextProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.hourAndMinutes)")
            modTemplate.line2TextProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.sgv)\(currentNightscoutData.bgdeltaString.cleanFloatValue)\(currentNightscoutData.bgdeltaArrow)")
            template = modTemplate
        case .modularLarge:
            let modTemplate = CLKComplicationTemplateModularLargeStandardBody()
            
            modTemplate.headerTextProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
            modTemplate.body1TextProvider = CLKSimpleTextProvider(text: "")
            modTemplate.body2TextProvider = CLKSimpleTextProvider(text: "")
            if self.oldNightscoutData.count > 1 {
                modTemplate.body1TextProvider = CLKSimpleTextProvider(text: self.getOneBigLine(self.oldNightscoutData[1]))
            }
            if self.oldNightscoutData.count > 2 {
                modTemplate.body2TextProvider = CLKSimpleTextProvider(text: self.getOneBigLine(self.oldNightscoutData[2]))
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
    
    // If the age is older than 59 minutes => return 60 in that case
    func getAgeOfDataInMinutes(_ time : NSNumber) -> Float {
        
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        let difference = (currentTime - time.int64Value) / 60000
        if difference > 59 {
            return 60
        }
        return Float(difference)
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
