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
           
            var line1TextProvider : CLKTextProvider
            var line2TextProvider : CLKTextProvider
            if useRelativeTimeWhenPossible {
                line1TextProvider = CLKSimpleTextProvider(text: getSgvAndArrow(currentNightscoutData, " "))
                line1TextProvider.tintColor = UIColorChanger.getBgColor(
                    UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
                line2TextProvider = getRelativeDateTextProvider(for: currentNightscoutData.time)
            } else {
                line1TextProvider = CLKSimpleTextProvider(text: "\(currentNightscoutData.hourAndMinutes)")
                line1TextProvider.tintColor = UIColorChanger.getBgColor(
                    UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
                line2TextProvider = CLKSimpleTextProvider(text: "\(UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))\(UnitsConverter.mgdlToDisplayUnitsWithSign(currentNightscoutData.bgdeltaString))\(currentNightscoutData.bgdeltaArrow)")
            }
            let modTemplate = CLKComplicationTemplateModularSmallStackText(line1TextProvider: line1TextProvider,
                                                                           line2TextProvider: line2TextProvider)
            template = modTemplate
        case .modularLarge:
            
            if useRelativeTimeWhenPossible {

                let row1Col1 = CLKSimpleTextProvider(text: getOneLine(currentNightscoutData))
                row1Col1.tintColor = UIColorChanger.getBgColor(
                    UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
                let row1Col2 = getRelativeDateTextProvider(for: currentNightscoutData.time)
                var row2Col1 = CLKSimpleTextProvider(text: "")
                var row2Col2 = CLKSimpleTextProvider(text: "")
                var row3Col1 = CLKSimpleTextProvider(text: "")
                var row3Col2 = CLKSimpleTextProvider(text: "")
                if self.oldNightscoutData.count > 1 {
                    let nightscoutData = self.oldNightscoutData[1]
                    row2Col1 = CLKSimpleTextProvider(text: getOneLine(nightscoutData))
                    row2Col2 = getRelativeDateTextProvider(for: nightscoutData.time) as? CLKSimpleTextProvider ?? row2Col2
                }
                if self.oldNightscoutData.count > 2 {
                    let nightscoutData = self.oldNightscoutData[2]
                    row3Col1 = CLKSimpleTextProvider(text: getOneLine(nightscoutData))
                    row3Col2 = getRelativeDateTextProvider(for: nightscoutData.time) as? CLKSimpleTextProvider ?? row3Col2
                }
                
                template = CLKComplicationTemplateModularLargeColumns(
                    row1Column1TextProvider: row1Col1, row1Column2TextProvider: row1Col2,
                    row2Column1TextProvider: row2Col1, row2Column2TextProvider: row2Col2,
                    row3Column1TextProvider: row3Col1, row3Column2TextProvider: row3Col2)
            } else {
                
                let headerTextProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
                var body1TextProvider = CLKSimpleTextProvider(text: "")
                var body2TextProvider = CLKSimpleTextProvider(text: "")
                if self.oldNightscoutData.count > 1 {
                    body1TextProvider = CLKSimpleTextProvider(text: self.getOneBigLine(self.oldNightscoutData[1]))
                }
                if self.oldNightscoutData.count > 2 {
                    body2TextProvider = CLKSimpleTextProvider(text: self.getOneBigLine(self.oldNightscoutData[2]))
                }
                template = CLKComplicationTemplateModularLargeStandardBody(headerTextProvider: headerTextProvider, body1TextProvider: body1TextProvider, body2TextProvider:  body2TextProvider)

            }
        case .utilitarianSmall:

            let textProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
            textProvider.tintColor = UIColorChanger.getBgColor(
                UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
            template = CLKComplicationTemplateUtilitarianSmallFlat(textProvider: textProvider)
        case .utilitarianLarge:
            
            let imageProvider = CLKImageProvider(onePieceImage: UIImage(named: "Complication/Circular")!)
            let textProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
            textProvider.tintColor = UIColorChanger.getBgColor(
                UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
            template = CLKComplicationTemplateUtilitarianLargeFlat(textProvider: textProvider, imageProvider: imageProvider)
        case .circularSmall:

            let textProvider = CLKSimpleTextProvider(text:
                UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
            textProvider.tintColor = UIColorChanger.getBgColor(
                UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
            
            let fillFraction = self.getAgeOfDataInMinutes(currentNightscoutData.time) / 60
            let ringStyle = CLKComplicationRingStyle.closed
            template = CLKComplicationTemplateCircularSmallRingText(textProvider: textProvider,
                                                                    fillFraction: fillFraction,
                                                                    ringStyle: ringStyle)
        case .graphicCorner:
            if #available(watchOSApplicationExtension 5.0, *) {

                let outerTextProvider = CLKSimpleTextProvider(text: self.getOneShortLine(currentNightscoutData))
                outerTextProvider.tintColor = UIColorChanger.getBgColor(
                    UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
                let innerTextProvider = CLKSimpleTextProvider(text: self.getLastReadingTime(currentNightscoutData))
                template = CLKComplicationTemplateGraphicCornerStackText(innerTextProvider: innerTextProvider, outerTextProvider: outerTextProvider)
            } else {
                abort()
            }
        case .graphicCircular:
            if #available(watchOSApplicationExtension 5.0, *) {

                let centerTextProvider = CLKSimpleTextProvider(text: "\(UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))")
                centerTextProvider.tintColor = UIColorChanger.getBgColor(
                    UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
                let gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: UIColor.black, fillFraction: CLKSimpleGaugeProviderFillFractionEmpty)
                template = CLKComplicationTemplateGraphicCircularClosedGaugeText(gaugeProvider: gaugeProvider, centerTextProvider: centerTextProvider)
            } else {
                abort()
            }
        case .graphicBezel:
            if #available(watchOSApplicationExtension 5.0, *) {

                let textProvider = CLKSimpleTextProvider(text: self.getOneBigLine(currentNightscoutData))
                textProvider.tintColor = UIColorChanger.getBgColor(
                    UnitsConverter.mgdlToDisplayUnits(currentNightscoutData.sgv))
                let modImageTemplate = CLKComplicationTemplateGraphicCircularImage(imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(named: "Complication/Graphic Circular")!))
                template = CLKComplicationTemplateGraphicBezelCircularText(circularTemplate: modImageTemplate)
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
        return "\(data.hourAndMinutes) \(UnitsConverter.mgdlToDisplayUnits(data.sgv))\(UnitsConverter.mgdlToDisplayUnitsWithSign(data.bgdeltaString))\(data.bgdeltaArrow)"
    }
    
    // Display 11:24
       func getLastReadingTime(_ data : NightscoutData) -> String {
           return "\(data.hourAndMinutes)"
       }
    
    // Displays 113 ↗ +2
    func getOneLine(_ data : NightscoutData) -> String {
        return "\(getSgvAndArrow(data, " "))\t\(UnitsConverter.mgdlToDisplayUnitsWithSign(data.bgdeltaString))"
    }
    
    // Displays 113↗+2
    func getOneShortLine(_ data : NightscoutData) -> String {
        return "\(getSgvAndArrow(data, ""))\(UnitsConverter.mgdlToDisplayUnitsWithSign(data.bgdeltaString))"
    }
    
    func getSgvAndArrow(_ data: NightscoutData, _ separator: String) -> String {
        
        // compact arrow to one character (space requirements!)
        var bgdeltaArrow = data.bgdeltaArrow
        if bgdeltaArrow == "↑↑" {
            bgdeltaArrow = "⇈"
        } else if bgdeltaArrow == "↓↓" {
            bgdeltaArrow = "⇊"
        }
        
        return [UnitsConverter.mgdlToDisplayUnits(data.sgv), bgdeltaArrow].joined(separator: separator)
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
            template = CLKComplicationTemplateCircularSmallRingImage(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(named: "Complication/Circular")!), fillFraction: CLKSimpleGaugeProviderFillFractionEmpty, ringStyle: CLKComplicationRingStyle.closed)
        default: break
        }
        handler(template)
    }
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(identifier: "nightguardComplication", displayName: "Nightguard",
                                      supportedFamilies: [CLKComplicationFamily.circularSmall,
                                                          CLKComplicationFamily.graphicBezel,
                                                          CLKComplicationFamily.graphicCorner,
                                                          CLKComplicationFamily.graphicCircular,
                                                          CLKComplicationFamily.modularLarge,
                                                          CLKComplicationFamily.modularSmall,
                                                          CLKComplicationFamily.utilitarianLarge,
                                                          CLKComplicationFamily.utilitarianSmall])
        ]
        // Call the handler with the currently supported complication descriptors
        handler(descriptors)
    }
}
