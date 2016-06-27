//
//  ChartPainter.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 01.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import WatchKit
import Foundation

class ChartPainter {
    let GREEN :  UIColor = UIColor.init(red: 0.48, green: 0.9, blue: 0, alpha: 1)
    let DARK : UIColor = UIColor.init(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
    let BLACK : UIColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 1)
    let LIGHTGRAY : UIColor = UIColor.init(red: 1, green: 1, blue: 1, alpha: 0.5)
    let DARKGRAY : UIColor = UIColor.init(red: 1, green: 1, blue: 1, alpha: 0.1)
    let YELLOW : UIColor = UIColor.init(red: 1, green: 1, blue: 0, alpha: 1)
    let RED : UIColor = UIColor.init(red: 1, green: 0, blue: 0, alpha: 1)
    let BLUE : UIColor = UIColor.init(red: 0, green: 0, blue: 1, alpha: 1)
    
    let halfHour : Double = 1800
    let fullHour : Double = 3600
    
    var canvasWidth : Int = 165
    var canvasHeight : Int = 125
    
    var maximumXValue : Double = 0
    var minimumXValue : Double = Double.infinity
    var maximumYValue : Float = 200
    var minimumYValue : Float = 40

    var size : CGSize
    
    init(canvasWidth : Int, canvasHeight : Int) {
        size = CGSize.init(width: canvasWidth, height: canvasHeight)
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }
    
    /* 
     * The upper- and lowerBoundGoodValue is the gray box that will be painted in the diagram.
     * It marks the blood values that are called "good".
     * Values out of this area will cause an alarm signal to be played!
     *
     * But of cause the alarming is out of the scope of this class!
     */
    func drawImage(days : [[BloodSugar]], upperBoundNiceValue : Float, lowerBoundNiceValue : Float) -> UIImage? {

        // we need at least one day => otherwise paint nothing
        if days.count == 1 {
            return nil
        }
        // we need at least 2 values - otherwise paint nothing and return empty image!
        if days[0].count <= 1 {
            return nil
        }
        
        adjustMinMaxXYCoordinates(days, upperBoundNiceValue: upperBoundNiceValue, lowerBoundNiceValue: lowerBoundNiceValue)
        
        // Setup our context
        let opaque = false
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
        let context = UIGraphicsGetCurrentContext()
        
        // Setup complete, do drawing here
        paintNicePartArea(context!, upperBoundNiceValue: upperBoundNiceValue, lowerBoundNiceValue: lowerBoundNiceValue)
        
        var nrOfDay = 0
        for bloodValues in days {
            nrOfDay = nrOfDay + 1
            paintBloodValues(context!, bgValues: bloodValues, foregroundColor: getColor(nrOfDay))
        }
        
        paintFullHourText()
        
        // Drawing complete, retrieve the finished image and cleanup
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    // Returns a different Color for each different day
    private func getColor(nrOfDay : Int) -> CGColor {
        
        switch nrOfDay {
            case 2: return LIGHTGRAY.CGColor
            case 3: return YELLOW.CGColor
            case 4: return RED.CGColor
            case 5: return BLUE.CGColor
            
            default: return GREEN.CGColor
        }
    }
    
    func paintBloodValues(context : CGContext, bgValues : [BloodSugar], foregroundColor : CGColor) {
        CGContextSetStrokeColorWithColor(context, foregroundColor)
        CGContextBeginPath(context)
        
        let maxPoints : Int = bgValues.count
        if maxPoints == 0 {
            // no values that could be painted
            return
        }
        for currentPoint in 1...maxPoints-1 {
            
            CGContextMoveToPoint(context,
                                 calcXValue(bgValues[currentPoint-1].timestamp),
                                 calcYValue(bgValues[currentPoint-1].value))
            CGContextAddLineToPoint(context,
                                    calcXValue(bgValues[currentPoint].timestamp),
                                    calcYValue(bgValues[currentPoint].value))
        }
        CGContextStrokePath(context)
    }
    
    // Paint the part between upperBound and lowerBoundValue in gray
    func paintNicePartArea(context : CGContext, upperBoundNiceValue : Float, lowerBoundNiceValue : Float) {
        
        // paint the rectangle
        CGContextSetLineWidth(context, 2.0)
        CGContextSetFillColorWithColor(context, DARKGRAY.CGColor)
        let goodPart = CGRect(origin: CGPoint.init(x: 0, y: calcYValue(upperBoundNiceValue)), size: CGSize.init(width: canvasWidth, height: Int(calcYValue(lowerBoundNiceValue) - calcYValue(upperBoundNiceValue))))
        CGContextFillRect(context, goodPart)
        
        // paint the upper/lower bounds text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .Left
        let attrs = [NSFontAttributeName: UIFont(name: "Helvetica Bold", size: 14)!,
                     NSParagraphStyleAttributeName: paragraphStyle,
                     NSForegroundColorAttributeName: UIColor.grayColor()]
        
        let upperBoundString = upperBoundNiceValue.cleanValue
        upperBoundString.drawWithRect(
            CGRect(x: 5, y: CGFloat.init(calcYValue(upperBoundNiceValue)), width: 40, height: 14),
                options: .UsesLineFragmentOrigin, attributes: attrs, context: nil)
        
        let lowerBoundString = lowerBoundNiceValue.cleanValue
        lowerBoundString.drawWithRect(
            CGRect(x: 5, y: min(CGFloat.init(calcYValue(lowerBoundNiceValue)-15), value2: CGFloat.init(canvasHeight-40)), width: 40, height: 14),
                options: .UsesLineFragmentOrigin, attributes: attrs, context: nil)

    }
    
    func min(value1 : CGFloat, value2 : CGFloat) -> CGFloat {
        if value1 < value2 {
            return value1
        }
        return value2
    }
    
    // Paints the X-Axis Text
    func paintFullHourText() {
        // Draw the time
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .Center
        let attrs = [NSFontAttributeName: UIFont(name: "Helvetica Bold", size: 14)!,
                     NSParagraphStyleAttributeName: paragraphStyle,
                     NSForegroundColorAttributeName: UIColor.grayColor()]
        
        if durationIsMoreThan6Hours(minimumXValue, maxTimestamp: maximumXValue) {
            paintEverySecondHour(attrs)
        } else {
            paintHalfHourTimestamps(attrs)
        }
    }
    
    func durationIsMoreThan6Hours(minTimestamp : Double, maxTimestamp : Double) -> Bool {
        return maxTimestamp - minTimestamp > 6 * 60 * 60 * 1000
    }
    
    func paintEverySecondHour(attrs : [String : AnyObject]) {
        let halfHours = determineEverySecondHourBetween(minimumXValue, maxTimestamp: maximumXValue)
        
        let hourFormat = NSDateFormatter()
        hourFormat.dateFormat = "HH:mm"
        for timestamp in halfHours {
            let hourString : String = hourFormat.stringFromDate(NSDate(timeIntervalSince1970 : timestamp / 1000))
            hourString.drawWithRect(CGRect(x: calcXValue(timestamp)-25, y: CGFloat.init(canvasHeight-20), width: 50, height: 14),
                                    options: .UsesLineFragmentOrigin, attributes: attrs, context: nil)
            
        }
    }
    
    func determineEverySecondHourBetween(minTimestamp : Double, maxTimestamp : Double) -> [Double] {
        
        let minDate = NSDate(timeIntervalSince1970: minTimestamp / 1000)
        let maxDate = NSDate(timeIntervalSince1970: maxTimestamp / 1000)
        
        var currentDate = minDate
        var evenHours : [Double] = []
        var stop : Bool
        
        repeat {
            let nextEvenHour = getNextEvenHour(currentDate);
            if nextEvenHour.compare(maxDate) == .OrderedAscending {
                evenHours.append(nextEvenHour.timeIntervalSince1970 * 1000)
                stop = false
            } else {
                stop = true
            }
            currentDate = nextEvenHour
        } while !stop
        
        return evenHours
    }
    
    func paintHalfHourTimestamps(attrs : [String : AnyObject]) {
        let halfHours = determineHalfHoursBetween(minimumXValue, maxTimestamp: maximumXValue)
        
        let hourFormat = NSDateFormatter()
        hourFormat.dateFormat = "HH:mm"
        for timestamp in halfHours {
            let hourString : String = hourFormat.stringFromDate(NSDate(timeIntervalSince1970 : timestamp / 1000))
            hourString.drawWithRect(CGRect(x: calcXValue(timestamp)-25, y: CGFloat.init(canvasHeight-20), width: 50, height: 14),
                                    options: .UsesLineFragmentOrigin, attributes: attrs, context: nil)
            
        }
    }
    
    func determineHalfHoursBetween(minTimestamp : Double, maxTimestamp : Double) -> [Double] {
        
        let minDate = NSDate(timeIntervalSince1970: minTimestamp / 1000)
        let maxDate = NSDate(timeIntervalSince1970: maxTimestamp / 1000)
        
        var currentDate = minDate
        var halfHours : [Double] = []
        var stop : Bool
        
        repeat {
            let nextHalfHour = getNextHalfHour(currentDate);
            if nextHalfHour.compare(maxDate) == .OrderedAscending {
                halfHours.append(nextHalfHour.timeIntervalSince1970 * 1000)
                stop = false
            } else {
                stop = true
            }
            currentDate = nextHalfHour
        } while !stop
        
        return halfHours
    }
    
    // Returns e.g. 04:00 for 02:00 o'clock.
    func getNextEvenHour(date : NSDate) -> NSDate {
        
        let cal = NSCalendar.currentCalendar()
        
        let hour = cal.component(NSCalendarUnit.Hour, fromDate: date)
        
        if isEven(hour + 1) {
            return cal.dateBySettingHour(hour, minute: 0, second: 0, ofDate: date, options: NSCalendarOptions())!.dateByAddingTimeInterval(fullHour)
        } else {
            return cal.dateBySettingHour(hour + 1, minute: 00, second: 0, ofDate: date, options: NSCalendarOptions())!.dateByAddingTimeInterval(fullHour)
        }
    }
    
    func isEven(hour : Int) -> Bool {
        return hour % 2 == 0
    }
    
    func getNextHalfHour(date : NSDate) -> NSDate {
        
        let cal = NSCalendar.currentCalendar()
        
        let hour = cal.component(NSCalendarUnit.Hour, fromDate: date)
        let minute = cal.component(NSCalendarUnit.Minute, fromDate: date)
        
        if minute < 30 {
            return cal.dateBySettingHour(hour, minute: 0, second: 0, ofDate: date, options: NSCalendarOptions())!.dateByAddingTimeInterval(halfHour)
        } else {
            return cal.dateBySettingHour(hour, minute: 30, second: 0, ofDate: date, options: NSCalendarOptions())!.dateByAddingTimeInterval(halfHour)
        }
    }
    
    func adjustMinMaxXYCoordinates(
            days : [[BloodSugar]],
            upperBoundNiceValue : Float,
            lowerBoundNiceValue : Float) {
        
        maximumXValue = -1 * Double.infinity
        minimumXValue = Double.infinity
        maximumYValue = upperBoundNiceValue
        minimumYValue = lowerBoundNiceValue
        
        (minimumXValue, maximumXValue, minimumYValue, maximumYValue) = adjustMinMax(days, minimumXValue: minimumXValue, maximumXValue: maximumXValue, minimumYValue: minimumYValue, maximumYValue: maximumYValue)
    }
    
    func adjustMinMax(days : [[BloodSugar]], minimumXValue : Double, maximumXValue : Double, minimumYValue : Float, maximumYValue : Float) -> (Double, Double, Float, Float) {
        
        var newMinXValue = minimumXValue
        var newMaxXValue = maximumXValue
        
        var newMinYValue = minimumYValue
        var newMaxYValue = maximumYValue
        
        for bgValues in days {
            for bgValue in bgValues {
                if bgValue.value < newMinYValue {
                    newMinYValue = bgValue.value
                }
                if bgValue.value > newMaxYValue {
                    newMaxYValue = bgValue.value
                }
            
                if bgValue.timestamp < newMinXValue {
                    newMinXValue = bgValue.timestamp
                }
                if bgValue.timestamp > newMaxXValue {
                    newMaxXValue = bgValue.timestamp
                }
            }
        }
        
        return (newMinXValue, newMaxXValue, newMinYValue, newMaxYValue)

    }
    func calcXValue(x : Double) -> CGFloat {
        return CGFloat.init(stretchedXValue(x));
    }
    
    func calcYValue(y : Float) -> CGFloat {

        var calculatedY : Float = stretchedYValue(y)
        if calculatedY > Float(Int.max) {
            calculatedY = Float(Int.max)
        }
        let mirroredY : Int = canvasHeight - Int(calculatedY)
        let cgfloat : CGFloat = CGFloat(mirroredY)
        
        return cgfloat
    }
    
    func stretchedXValue(x : Double) -> Double {
        var range = maximumXValue - minimumXValue
        if range == 0 {
            // prevent a division by zero
            range = 1
        }
        return (Double(canvasWidth) / Double(range)) * Double(x - minimumXValue)
    }
    
    func stretchedYValue(y : Float) -> Float {
        var range = maximumYValue - minimumYValue
        if range == 0 {
            // prevent a division by zero
            range = 1
        }
        return (Float(canvasHeight) / Float(range)) * (y - minimumYValue)
    }
}