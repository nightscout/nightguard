//
//  ComplicationController.swift
//  scoutwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import ClockKit


class ComplicationController: NSObject, CLKComplicationDataSource {
    
    var oldValues : [NightscoutData] = []
    
    func getNextRequestedUpdateDateWithHandler(handler: (NSDate?) -> Void) {
        // Update every 5 Minutes => but this is just a nice wish
        // => Apple will allow maybe just 30 minutes :(
        handler(NSDate(timeIntervalSinceNow: 60*5))
    }
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirectionsForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.None])
    }
    
    func getCurrentTimelineEntryForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimelineEntry?) -> Void) {
        
        NightscoutService.singleton.readCurrentDataForPebbleWatch({(currentNightscoutData) -> Void in

            self.oldValues.insert(currentNightscoutData, atIndex: 0)
            var template : CLKComplicationTemplate? = nil
            
            switch complication.family {
            case .ModularSmall:
                let modTemplate = CLKComplicationTemplateModularSmallStackText()
                
                modTemplate.line1TextProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.hourAndMinutes)")
                modTemplate.line2TextProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.sgv)\(currentNightscoutData.bgdeltaString.cleanFloatValue)\(currentNightscoutData.bgdeltaArrow)")
                template = modTemplate
            case .ModularLarge:
                let modTemplate = CLKComplicationTemplateModularLargeStandardBody()
                
                modTemplate.headerTextProvider = CLKSimpleTextProvider(text: self.getOneBigLine(self.oldValues[0]))
                modTemplate.body1TextProvider = CLKSimpleTextProvider(text: "")
                modTemplate.body2TextProvider = CLKSimpleTextProvider(text: "")
                if self.oldValues.count > 1 {
                    modTemplate.body1TextProvider = CLKSimpleTextProvider(text: self.getOneBigLine(self.oldValues[1]))
                }
                if self.oldValues.count > 2 {
                    modTemplate.body2TextProvider = CLKSimpleTextProvider(text: self.getOneBigLine(self.oldValues[2]))
                }
                template = modTemplate
            case .UtilitarianSmall:
                let modTemplate = CLKComplicationTemplateUtilitarianSmallFlat()
                modTemplate.textProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
                template = modTemplate
            case .UtilitarianLarge:
                let modTemplate = CLKComplicationTemplateUtilitarianLargeFlat()
                modTemplate.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Complication/Circular")!)
                modTemplate.textProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
                template = modTemplate
            case .CircularSmall:
                let template = CLKComplicationTemplateCircularSmallRingText()
                template.textProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.sgv)")
                
                template.fillFraction = self.getAgeOfDataInMinutes(currentNightscoutData.time) / 60
                template.ringStyle = CLKComplicationRingStyle.Closed
            }
            
            if template != nil {
                let timelineEntry = CLKComplicationTimelineEntry(date: NSDate(), complicationTemplate: template!)
                handler(timelineEntry)
            }
        })
    }
    
    // Display 11:24 113+2
    func getOneBigLine(data : NightscoutData) -> String {
        return "\(data.hourAndMinutes) \(data.sgv)\(data.bgdeltaString.cleanFloatValue)\(data.bgdeltaArrow)"
    }
    
    // If the age is older than 59 minutes => return 60 in that case
    func getAgeOfDataInMinutes(time : NSNumber) -> Float {
        
        let currentTime = Int64(NSDate().timeIntervalSince1970 * 1000)
        let difference = (currentTime - time.longLongValue) / 60000
        if difference > 59 {
            return 60
        }
        return Float(difference)
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
            let template = CLKComplicationTemplateCircularSmallRingImage()
            template.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Complication/Circular")!)
        }
        handler(template)
    }
    
}
