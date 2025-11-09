//
//  UIColorChanger.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 02.01.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit
import SwiftUI
#if !os(iOS)
import WatchKit
#endif

/*
 * Calculates the Colors for the different UI Elements
 * corresponding to current blood and time values.
 * E.g. paints the blood glucose value red if above 200.
 */
class UIColorChanger {
    
    // Changes the color to red if blood glucose is bad :-/
    static func getBgColor(_ bg : String) -> UIColor {

        guard var bgNumber : Float = Float(bg) else {
            return UIColor.white
        }
        
        if (UserDefaultsRepository.units.value == Units.mmol) {
            bgNumber = UnitsConverter.displayValueToMgdl(bgNumber)
        }
        
        if bgNumber > 200 {
            return UIColor.nightguardRed()
        } else if bgNumber > 180 {
            return UIColor.nightguardYellow()
        } else if bgNumber > 70 {
            return UIColor.nightguardGreen()
        } else if bgNumber > 55 {
            return UIColor.nightguardYellow()
        } else {
            return UIColor.nightguardRed()
        }
    }
    
    // Changes the color to red if blood glucose is bad :-/
    static func getBgColorFromMgdl(_ bgInMgdl : String) -> UIColor {

        guard let bgNumber : Float = Float(bgInMgdl) else {
            return UIColor.white
        }
        
        if bgNumber > 200 {
            return UIColor.nightguardRed()
        } else if bgNumber > 180 {
            return UIColor.nightguardYellow()
        } else if bgNumber > 70 {
            return UIColor.nightguardGreen()
        } else if bgNumber > 55 {
            return UIColor.nightguardYellow()
        } else {
            return UIColor.nightguardRed()
        }
    }
    
    static func getDeltaLabelColor(_ bgdelta : Float) -> UIColor {
        
        let absoluteDelta = abs(bgdelta)
        if (UserDefaultsRepository.units.value == Units.mgdl) {
            if (absoluteDelta >= 10) {
                return UIColor.nightguardRed()
            } else if (absoluteDelta >= 5) {
                return UIColor.nightguardYellow()
            } else {
                return UIColor.white
            }
        }
        
        if (absoluteDelta >= 0.6) {
            return UIColor.nightguardRed()
        } else if (absoluteDelta >= 0.3) {
            return UIColor.nightguardYellow()
        } else {
            return UIColor.white
        }
    }
    
    static func getTimeLabelColor(_ lastUpdate : NSNumber) -> UIColor {
        
        let lastUpdateAsNSDate : Date = Date(timeIntervalSince1970: lastUpdate.doubleValue / 1000)
        let timeInterval = Date().timeIntervalSince(lastUpdateAsNSDate)
        if (timeInterval > 15*60) {
            return UIColor.nightguardRed()
        } else if (timeInterval > 7*60) {
            return UIColor.nightguardYellow()
        } else {
            return UIColor.white
        }
    }
    
    static func getTimeLabelColor(fromDouble lastUpdate : Double) -> UIColor {
        
        let lastUpdateAsNSDate : Date = Date(timeIntervalSince1970: lastUpdate / 1000)
        let timeInterval : Int = Int(Date().timeIntervalSince(lastUpdateAsNSDate))
        if (timeInterval > 15*60) {
            return UIColor.nightguardRed()
        } else if (timeInterval > 7*60) {
            return UIColor.nightguardYellow()
        } else {
            return UIColor.white
        }
    }
    static func getBatteryLabelColor(_ percentageString : String) -> UIColor {
        
        guard let percentage : Int = Int(percentageString.removing(charactersOf: "%")) else {
            return UIColor.white
        }
        
        if (percentage < 20) {
            return UIColor.nightguardRed()
        } else if (percentage < 40) {
            return UIColor.nightguardYellow()
        } else {
            return UIColor.white
        }
    }
    

    static func calculateCannulaAgeColor(cannulaAgeDate : Date) -> Color {
        return Color.white
    }
}
