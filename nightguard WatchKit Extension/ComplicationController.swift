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
    
    // this is a setting that can migrate in app settings screen: the user can preffer relative or absolute time as complication data (relative time is automatically updated by watchOS)
    let useRelativeTimeWhenPossible: Bool = true
    
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
            
            if useRelativeTimeWhenPossible {
                modTemplate.line1TextProvider = CLKSimpleTextProvider(text: getSgvAndArrow(currentNightscoutData, " "))
                modTemplate.line2TextProvider = getRelativeDateTextProvider(for: currentNightscoutData.time)
            } else {
                modTemplate.line1TextProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.hourAndMinutes)")
                modTemplate.line2TextProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.sgv)\(currentNightscoutData.bgdeltaString.cleanFloatValue)\(currentNightscoutData.bgdeltaArrow)")
            }
            template = modTemplate
        case .modularLarge:
            if useRelativeTimeWhenPossible {
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
            } else {
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
            }
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
            let modTemplate = CLKComplicationTemplateCircularSmallRingText()
            modTemplate.textProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.sgv)")
            
            modTemplate.fillFraction = self.getAgeOfDataInMinutes(currentNightscoutData.time) / 60
            modTemplate.ringStyle = CLKComplicationRingStyle.closed
            template = modTemplate
        case .graphicCorner:
            if #available(watchOSApplicationExtension 5.0, *) {
                 let modTemplate = CLKComplicationTemplateGraphicCornerStackText()
                modTemplate.outerTextProvider = CLKSimpleTextProvider(text: self.getOneShortLine(currentNightscoutData))
                modTemplate.innerTextProvider = CLKSimpleTextProvider(text: self.getLastReadingTime(currentNightscoutData))
                template = modTemplate
            } else {
                abort()
            }
        case .graphicCircular:
            if #available(watchOSApplicationExtension 5.0, *) {
                let modTemplate = CLKComplicationTemplateGraphicCircularClosedGaugeText()
                modTemplate.centerTextProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.sgv)")
                modTemplate.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: UIColor.black, fillFraction: 0.0)
                template = modTemplate
            } else {
                abort()
            }
        case .graphicBezel:
            if #available(watchOSApplicationExtension 5.0, *) {
                let modTemplate = CLKComplicationTemplateGraphicBezelCircularText()
                modTemplate.textProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
                let modImageTemplate = CLKComplicationTemplateGraphicCircularImage()
                modImageTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(named: "Complication/Graphic Circular")!)
                modTemplate.circularTemplate = modImageTemplate
                template = modTemplate
            } else {
                abort()
            }
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
    
    // Display 11:24
       func getLastReadingTime(_ data : NightscoutData) -> String {
           return "\(data.hourAndMinutes)"
       }
    
    // Displays 113 ↗ +2
    func getOneLine(_ data : NightscoutData) -> String {
        return "\(getSgvAndArrow(data, " "))\t\(data.bgdeltaString.cleanFloatValue)"
    }
    
    // Displays 113↗+2
    func getOneShortLine(_ data : NightscoutData) -> String {
        return "\(getSgvAndArrow(data, ""))\(data.bgdeltaString.cleanFloatValue)"
    }
    
    func getSgvAndArrow(_ data: NightscoutData, _ separator: String) -> String {
        
        // compact arrow to one character (space requirements!)
        var bgdeltaArrow = data.bgdeltaArrow
        if bgdeltaArrow == "↑↑" {
            bgdeltaArrow = "⇈"
        } else if bgdeltaArrow == "↓↓" {
            bgdeltaArrow = "⇊"
        }
        
        return [data.sgv, bgdeltaArrow].joined(separator: separator)
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
        let isOlderThanTwoHours = getAgeOfDataInMinutes(time) >= 120
        return CLKRelativeDateTextProvider(date: date, style: .natural, units: isOlderThanTwoHours ? .hour : .minute)
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
