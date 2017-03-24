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
    // the height that can be used to paint the lines
    // this way the lines can't cross the x-axis labels
    var paintableHeight : Int = 100
    
    var maximumXValue : Double = 0
    var minimumXValue : Double = Double.infinity
    var maximumYValue : Float = 200
    var minimumYValue : Float = 40

    var size : CGSize
    
    init(canvasWidth : Int, canvasHeight : Int) {
        size = CGSize.init(width: canvasWidth, height: canvasHeight)
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.paintableHeight = canvasHeight - 30
    }
    
    /* 
     * The upper- and lowerBoundGoodValue is the gray box that will be painted in the diagram.
     * It marks the blood values that are called "good".
     * Values out of this area will cause an alarm signal to be played!
     *
     * But of cause the alarming is out of the scope of this class!
     
     * The position of the current value is returned as the second tuple element.
     * It is used to show the current value in the viewport.
     */
    func drawImage(days : [[BloodSugar]], maxYDisplayValue : CGFloat, upperBoundNiceValue : Float, lowerBoundNiceValue : Float) -> (UIImage?, Int) {

        // we need at least one day => otherwise paint nothing
        if days.count == 1 {
            return (nil, 0)
        }
        // we need at least 2 values - otherwise paint nothing and return empty image!
        if justOneOrLessValuesPerDiagram(days) {
            return (nil, 0)
        }
        
        adjustMinMaxXYCoordinates(days, maxYDisplayValue: maxYDisplayValue, upperBoundNiceValue: upperBoundNiceValue, lowerBoundNiceValue: lowerBoundNiceValue)
        
        // Setup our context
        let opaque = false
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
        let context = UIGraphicsGetCurrentContext()
        
        // Setup complete, do drawing here
        paintNicePartArea(context!, upperBoundNiceValue: upperBoundNiceValue, lowerBoundNiceValue: lowerBoundNiceValue)
        
        paintFullHourText(context!)
        
        var nrOfDay = 0
        var positionOfCurrentValue = 0
        for bloodValues in days {
            nrOfDay = nrOfDay + 1
            paintBloodValues(context!, bgValues: bloodValues, foregroundColor: getColor(nrOfDay).CGColor, maxBgValue: maxYDisplayValue)
            
            if nrOfDay == 1 && bloodValues.count > 0 {
                positionOfCurrentValue = Int(calcXValue(bloodValues.last!.timestamp))
            }
        }
        
        paintLegend(days.count)
        
        paintUpperLowerBoundLabels(context!, upperBoundNiceValue: upperBoundNiceValue, lowerBoundNiceValue: lowerBoundNiceValue)
        
        // Drawing complete, retrieve the finished image and cleanup
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return (image, positionOfCurrentValue)
    }
    
    private func justOneOrLessValuesPerDiagram(days : [[BloodSugar]]) -> Bool {
        for bloodValues in days {
            if bloodValues.count > 1 {
                // at least one diagram will have a line, painting makes sense
                return false
            }
        }
        return true
    }
    
    // Returns a different Color for each different day
    private func getColor(nrOfDay : Int) -> UIColor {
        
        switch nrOfDay {
            case 2: return LIGHTGRAY
            case 3: return YELLOW
            case 4: return RED
            case 5: return BLUE
            
            default: return GREEN
        }
    }
    
    private func paintBloodValues(context : CGContext, bgValues : [BloodSugar], foregroundColor : CGColor, maxBgValue : CGFloat) {
        CGContextSetStrokeColorWithColor(context, foregroundColor)
        CGContextBeginPath(context)
        
        let maxPoints : Int = bgValues.count
        if maxPoints <= 1 {
            // at least to points are needed to paint a stroke
            return
        }
        for currentPoint in 1...maxPoints-1 {
            
            let beginOfLineYValue = calcYValue(Float(min(CGFloat(bgValues[currentPoint-1].value), value2: maxBgValue)))
            let endOfLineYValue = calcYValue(Float(min(CGFloat(bgValues[currentPoint].value), value2: maxBgValue)))
    
            let maxYValue = calcYValue(Float(maxBgValue))
            
            useRedColorIfLineWillBeReducedToMaxYValue(
                context, beginOfLineYValue: beginOfLineYValue, endOfLineYValue: endOfLineYValue,
                maxYDisplayValue: maxYValue, color: foregroundColor)
            
            drawLine(context,
                     x1: calcXValue(bgValues[currentPoint-1].timestamp),
                     y1: beginOfLineYValue,
                     x2: calcXValue(bgValues[currentPoint].timestamp),
                     y2: endOfLineYValue)
        }
        CGContextStrokePath(context)
    }
    
    private func useRedColorIfLineWillBeReducedToMaxYValue(context : CGContext,
                                                           beginOfLineYValue : CGFloat, endOfLineYValue : CGFloat,
                                                           maxYDisplayValue : CGFloat, color : CGColor) {
        
        let intMaxYDisplayValue = Int(maxYDisplayValue)
        
        if Int(beginOfLineYValue) == intMaxYDisplayValue &&
            Int(endOfLineYValue) == intMaxYDisplayValue &&
            CGColorEqualToColor(color, GREEN.CGColor) {
            
            CGContextStrokePath(context);
            CGContextBeginPath(context);
            CGContextSetStrokeColorWithColor(context, RED.CGColor)
        } else {
            CGContextSetStrokeColorWithColor(context, color)
        }
    }
    
    private func drawLine(context : CGContext, x1 : CGFloat, y1 : CGFloat, x2 : CGFloat, y2 : CGFloat) {
        
        CGContextMoveToPoint(context, x1, y1)
        CGContextAddLineToPoint(context, x2, y2)
    }
    
    // Paint the part between upperBound and lowerBoundValue in gray
    private func paintNicePartArea(context : CGContext, upperBoundNiceValue : Float, lowerBoundNiceValue : Float) {
        
        // paint the rectangle
        CGContextSetLineWidth(context, 2.0)
        CGContextSetFillColorWithColor(context, DARKGRAY.CGColor)
        let goodPart = CGRect(origin: CGPoint.init(x: 0, y: calcYValue(upperBoundNiceValue)), size: CGSize.init(width: canvasWidth, height: Int(calcYValue(lowerBoundNiceValue) - calcYValue(upperBoundNiceValue))))
        CGContextFillRect(context, goodPart)
    }
    
    private func paintUpperLowerBoundLabels(context : CGContext, upperBoundNiceValue : Float, lowerBoundNiceValue : Float) {
        
        // paint the upper/lower bounds text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .Left
        let attrs = [NSFontAttributeName: UIFont(name: "Helvetica Bold", size: 14)!,
                     NSParagraphStyleAttributeName: paragraphStyle,
                     NSForegroundColorAttributeName: UIColor.grayColor()]
        
        var x = 5
        while (x < canvasWidth) {
            let upperBoundString = UnitsConverter.toDisplayUnits(upperBoundNiceValue.cleanValue)
            upperBoundString.drawWithRect(
                CGRect(x: CGFloat(x), y: CGFloat.init(calcYValue(upperBoundNiceValue)), width: 40, height: 14),
                options: .UsesLineFragmentOrigin, attributes: attrs, context: nil)
            
            let lowerBoundString = UnitsConverter.toDisplayUnits(lowerBoundNiceValue.cleanValue)
            lowerBoundString.drawWithRect(
                CGRect(x: CGFloat(x), y: CGFloat.init(calcYValue(lowerBoundNiceValue))-15, width: 40, height: 14),
                options: .UsesLineFragmentOrigin, attributes: attrs, context: nil)
            
            x = x + 200
        }
    }
    
    private func min(value1 : CGFloat, value2 : CGFloat) -> CGFloat {
        if value1 < value2 {
            return value1
        }
        return value2
    }
    
    // Paints the X-Axis Text
    private func paintFullHourText(context : CGContext) {
        // Draw the time
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .Center
        let attrs = [NSFontAttributeName: UIFont(name: "Helvetica Bold", size: 14)!,
                     NSParagraphStyleAttributeName: paragraphStyle,
                     NSForegroundColorAttributeName: UIColor.grayColor()]
        
        if durationIsMoreThan6Hours(minimumXValue, maxTimestamp: maximumXValue) && canvasWidth < 1920 {
            paintEverySecondHour(context, attrs: attrs)
        } else {
            paintHourTimestamps(context, attrs: attrs)
        }
    }
    
    private func paintLegend(nrOfNames : Int) {
        
        let names = ["D1", "D2", "D3", "D4", "D5"]
        let namesToDisplay = Array(names.prefix(nrOfNames))
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .Center
        var attrs = [NSFontAttributeName: UIFont(name: "Helvetica Bold", size: 14)!,
                     NSParagraphStyleAttributeName: paragraphStyle,
                     NSForegroundColorAttributeName: UIColor.grayColor()]
        
        var i : Int = 0
        for name in namesToDisplay {
            
            i = i + 1
            attrs.updateValue(getColor(i), forKey: NSForegroundColorAttributeName)
            let xPosition = canvasWidth - 20 * nrOfNames + i * 20 - 20
            name.drawWithRect(CGRect(x: xPosition, y: 0, width: 20, height: 14),
                                options: .UsesLineFragmentOrigin, attributes: attrs, context: nil)
        }
    }
    
    private func durationIsMoreThan6Hours(minTimestamp : Double, maxTimestamp : Double) -> Bool {
        return maxTimestamp - minTimestamp > 6 * 60 * 60 * 1000
    }
    
    private func paintEverySecondHour(context : CGContext, attrs : [String : AnyObject]) {
        let halfHours = determineEverySecondHourBetween(minimumXValue, maxTimestamp: maximumXValue)
        
        let hourFormat = NSDateFormatter()
        hourFormat.dateFormat = "HH:mm"
        for timestamp in halfHours {
            let hourString : String = hourFormat.stringFromDate(NSDate(timeIntervalSince1970 : timestamp / 1000))
            let x = calcXValue(timestamp)
            hourString.drawWithRect(CGRect(x: x-25, y: CGFloat.init(canvasHeight-20), width: 50, height: 14),
                                    options: .UsesLineFragmentOrigin, attributes: attrs, context: nil)
            
            CGContextBeginPath(context)
            drawLine(context, x1: x, y1: 0, x2: x, y2: CGFloat(canvasHeight) - 20)
            CGContextStrokePath(context)
        }
    }
    
    private func determineEverySecondHourBetween(minTimestamp : Double, maxTimestamp : Double) -> [Double] {
        
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
    
    private func paintHourTimestamps(context : CGContext, attrs : [String : AnyObject]) {
        let hours = determineHoursBetween(minimumXValue, maxTimestamp: maximumXValue)
        
        let hourFormat = NSDateFormatter()
        hourFormat.dateFormat = "HH:mm"
        
        CGContextSetStrokeColorWithColor(context, BLACK.CGColor)
        for timestamp in hours {
            let hourString : String = hourFormat.stringFromDate(NSDate(timeIntervalSince1970 : timestamp / 1000))
            let x = calcXValue(timestamp)
            hourString.drawWithRect(CGRect(x: x-25, y: CGFloat.init(canvasHeight-20), width: 50, height: 14),
                                    options: .UsesLineFragmentOrigin, attributes: attrs, context: nil)
            
            CGContextBeginPath(context)
            drawLine(context, x1: x, y1: 0, x2: x, y2: CGFloat(canvasHeight) - 20)
            CGContextStrokePath(context)
        }
    }
    
    func determineHoursBetween(minTimestamp : Double, maxTimestamp : Double) -> [Double] {
        
        let minDate = NSDate(timeIntervalSince1970: minTimestamp / 1000)
        let maxDate = NSDate(timeIntervalSince1970: maxTimestamp / 1000)
        
        var currentDate = minDate
        var halfHours : [Double] = []
        var stop : Bool
        
        repeat {
            let nextHour = getNextHour(currentDate);
            if nextHour.compare(maxDate) == .OrderedAscending {
                halfHours.append(nextHour.timeIntervalSince1970 * 1000)
                stop = false
            } else {
                stop = true
            }
            currentDate = nextHour
        } while !stop
        
        return halfHours
    }
    
    // Returns e.g. 04:00 for 02:00 o'clock.
    private func getNextEvenHour(date : NSDate) -> NSDate {
        
        let cal = NSCalendar.currentCalendar()
        
        let hour = cal.component(NSCalendarUnit.Hour, fromDate: date)
        
        if isEven(hour + 1) {
            return cal.dateBySettingHour(hour, minute: 0, second: 0, ofDate: date, options: NSCalendarOptions())!.dateByAddingTimeInterval(fullHour)
        } else {
            return cal.dateBySettingHour(hour + 1, minute: 00, second: 0, ofDate: date, options: NSCalendarOptions())!.dateByAddingTimeInterval(fullHour)
        }
    }
    
    private func isEven(hour : Int) -> Bool {
        return hour % 2 == 0
    }
    
    private func getNextHour(date : NSDate) -> NSDate {
        
        let cal = NSCalendar.currentCalendar()
        
        let hour = cal.component(NSCalendarUnit.Hour, fromDate: date)
        
        return cal.dateBySettingHour(hour, minute: 0, second: 0, ofDate: date, options: NSCalendarOptions())!.dateByAddingTimeInterval(fullHour)
    }
    
    func adjustMinMaxXYCoordinates(
            days : [[BloodSugar]],
            maxYDisplayValue : CGFloat,
            upperBoundNiceValue : Float,
            lowerBoundNiceValue : Float) {
        
        maximumXValue = -1 * Double.infinity
        minimumXValue = Double.infinity
        maximumYValue = upperBoundNiceValue
        minimumYValue = lowerBoundNiceValue
        
        (minimumXValue, maximumXValue, minimumYValue, maximumYValue) = adjustMinMax(days, maxYDisplayValue: maxYDisplayValue, minimumXValue: minimumXValue, maximumXValue: maximumXValue, minimumYValue: minimumYValue, maximumYValue: maximumYValue)
    }
    
    private func adjustMinMax(days : [[BloodSugar]], maxYDisplayValue: CGFloat, minimumXValue : Double, maximumXValue : Double, minimumYValue : Float, maximumYValue : Float) -> (Double, Double, Float, Float) {
        
        var newMinXValue = minimumXValue
        var newMaxXValue = maximumXValue
        
        var newMinYValue = minimumYValue
        var newMaxYValue = Float(min(CGFloat(maximumYValue), value2: maxYDisplayValue))
        
        for bgValues in days {
            for bgValue in bgValues {
                if bgValue.value < newMinYValue {
                    newMinYValue = bgValue.value
                }
                if bgValue.value > newMaxYValue {
                    newMaxYValue = Float(min(CGFloat(bgValue.value), value2: maxYDisplayValue))
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
    
    private func calcXValue(x : Double) -> CGFloat {
        return CGFloat.init(stretchedXValue(x));
    }
    
    func calcYValue(y : Float) -> CGFloat {

        var calculatedY : Float = stretchedYValue(y)
        if calculatedY > Float(Int.max) {
            calculatedY = Float(Int.max)
        }
        let mirroredY : Int = paintableHeight - Int(calculatedY)
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
        return (Float(paintableHeight) / Float(range)) * (y - minimumYValue)
    }
}
