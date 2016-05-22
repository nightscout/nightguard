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
    let GREEN : UIColor = UIColor.init(red: 0.48, green: 0.9, blue: 0, alpha: 1)
    let DARK : UIColor = UIColor.init(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
    let BLACK : UIColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 1)
    let DARKGRAY : UIColor = UIColor.init(red: 1, green: 1, blue: 1, alpha: 0.5)
    
    
    var canvasWidth : Int = 165
    var canvasHeight : Int = 125
    
    var maximumXValue : Double = 0
    var minimumXValue : Double = Double.infinity
    var maximumYValue = 200
    var minimumYValue = 40

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
    func drawImage(bgValues : [BloodSugar], yesterdaysValues : [BloodSugar], upperBoundGoodValue : Int, lowerBoundGoodValue : Int) -> UIImage? {

        // we need at least 2 values - otherwise paint nothing and return empty image!
        if bgValues.count <= 1 {
            return nil
        }

        adjustMinMaxXYCoordinates(bgValues, yesterdaysValues: yesterdaysValues)
        
        // Setup our context
        let opaque = false
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
        let context = UIGraphicsGetCurrentContext()
        
        // Setup complete, do drawing here
        // Paint the part between 80 and 180 in gray
        CGContextSetLineWidth(context, 2.0)
        CGContextSetFillColorWithColor(context, DARK.CGColor)
        let goodPart = CGRect(origin: CGPoint.init(x: 0, y: calcYValue(upperBoundGoodValue)), size: CGSize.init(width: canvasWidth, height: Int(calcYValue(lowerBoundGoodValue) - calcYValue(upperBoundGoodValue))))
        CGContextFillRect(context, goodPart)

        paintBloodValues(context!, bgValues: bgValues, foregroundColor: GREEN.CGColor)
        paintBloodValues(context!, bgValues: yesterdaysValues, foregroundColor: DARKGRAY.CGColor)
        
        paintFullHourText()
        
        // Drawing complete, retrieve the finished image and cleanup
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func paintBloodValues(context : CGContext, bgValues : [BloodSugar], foregroundColor : CGColor) {
        CGContextSetStrokeColorWithColor(context, foregroundColor)
        CGContextBeginPath(context)
        
        let maxPoints : Int = bgValues.count
        for (var currentPoint = 1; currentPoint < maxPoints; currentPoint += 1) {
            
            CGContextMoveToPoint(context,
                                 calcXValue(bgValues[currentPoint-1].timestamp),
                                 calcYValue(bgValues[currentPoint-1].value))
            CGContextAddLineToPoint(context,
                                    calcXValue(bgValues[currentPoint].timestamp),
                                    calcYValue(bgValues[currentPoint].value))
        }
        CGContextStrokePath(context)
    }
    
    func paintFullHourText() {
        // Draw the time
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .Center
        let attrs = [NSFontAttributeName: UIFont(name: "HelveticaNeue-Thin", size: 14)!,
                     NSParagraphStyleAttributeName: paragraphStyle,
                     NSForegroundColorAttributeName: UIColor.whiteColor()]
        
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
    
    func getNextHalfHour(date : NSDate) -> NSDate {
        
        let cal = NSCalendar.currentCalendar()
        
        let hour = cal.component(NSCalendarUnit.Hour, fromDate: date)
        let minute = cal.component(NSCalendarUnit.Minute, fromDate: date)
        
        if minute < 30 {
            return cal.dateBySettingHour(hour, minute: 30, second: 0, ofDate: date, options: NSCalendarOptions())!
        } else {
            // catch exception if going over 0:00 o'clock
            if hour == 23 {
                return cal.dateBySettingHour(0, minute: 0, second: 0, ofDate: date, options: NSCalendarOptions())!
            } else {
                return cal.dateBySettingHour(hour + 1, minute: 0, second: 0, ofDate: date, options: NSCalendarOptions())!
            }
        }
    }
    
    func adjustMinMaxXYCoordinates(bgValues : [BloodSugar], yesterdaysValues : [BloodSugar]) {
        maximumXValue = -1 * Double.infinity
        minimumXValue = Double.infinity
        maximumYValue = Int.min
        minimumYValue = Int.max
        
        (minimumXValue, maximumXValue, minimumYValue, maximumYValue) = adjustMinMax(bgValues, minimumXValue: minimumXValue, maximumXValue: maximumXValue, minimumYValue: minimumYValue, maximumYValue: maximumYValue)
        
        (minimumXValue, maximumXValue, minimumYValue, maximumYValue) = adjustMinMax(yesterdaysValues, minimumXValue: minimumXValue, maximumXValue: maximumXValue, minimumYValue: minimumYValue, maximumYValue: maximumYValue)
    }
    
    func adjustMinMax(bgValues : [BloodSugar], minimumXValue : Double, maximumXValue : Double, minimumYValue : Int, maximumYValue : Int) -> (Double, Double, Int, Int) {
        
        var newMinXValue = minimumXValue
        var newMaxXValue = maximumXValue
        
        var newMinYValue = minimumYValue
        var newMaxYValue = maximumYValue
        
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
        
        return (newMinXValue, newMaxXValue, newMinYValue, newMaxYValue)

    }
    func calcXValue(x : Double) -> CGFloat {
        return CGFloat.init(stretchedXValue(x));
    }
    
    func calcYValue(y : Int) -> CGFloat {

        var calculatedY : Float = stretchedYValue(y)
        if calculatedY > Float(Int.max) {
            calculatedY = Float(Int.max)
        }
        let mirroredY : Int = canvasHeight - Int(calculatedY)
        let cgfloat : CGFloat = CGFloat(mirroredY)
        
        return cgfloat
    }
    
    func stretchedXValue(x : Double) -> Double {
        return Double(canvasWidth) / Double(maximumXValue - minimumXValue) * Double(x - minimumXValue)
    }
    
    func stretchedYValue(y : Int) -> Float {
        return Float(canvasHeight) / Float(maximumYValue - minimumYValue) * Float(y - minimumYValue)
    }
}