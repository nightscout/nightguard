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
    
    
    var canvasWidth : Int = 165
    var canvasHeight : Int = 125
    
    var maximumYValue = 200
    var minimumYValue = 40

    var size : CGSize
    
    init(canvasWidth : Int, canvasHeight : Int) {
        size = CGSize.init(width: canvasWidth, height: canvasHeight)
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }
    
    func drawImage(bgValues : [Int]) -> UIImage? {

        // we need at least 2 values - otherwise paint nothing and return empty image!
        if bgValues.count <= 1 {
            return nil
        }

        adjustMinMaxYCoordinates(bgValues)
        
        // Setup our context
        let opaque = false
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
        let context = UIGraphicsGetCurrentContext()
        
        // Setup complete, do drawing here
        // Paint the part between 80 and 180 in gray
        CGContextSetLineWidth(context, 2.0)
        CGContextSetFillColorWithColor(context, DARK.CGColor)
        let goodPart = CGRect(origin: CGPoint.init(x: 0, y: calcYValue(180)), size: CGSize.init(width: canvasWidth, height: Int(stretchedYValue(100 + minimumYValue))))
        CGContextFillRect(context, goodPart)

        //CGContextSetStrokeColorWithColor(context, UIColor.redColor().CGColor)
        //CGContextStrokeRect(context, CGRect(origin: CGPoint.init(x: 0, y: 0), size: CGSize.init(width: canvasWidth, height: canvasHeight)))
        
        // Paint the glucose data
        CGContextSetStrokeColorWithColor(context, GREEN.CGColor)
        CGContextBeginPath(context)
        
        let maxPoints : Int = bgValues.count
        for (var currentPoint = 1; currentPoint < maxPoints; currentPoint += 1) {
            
            CGContextMoveToPoint(context,
                calcXValue(currentPoint-1, xValuesCount: maxPoints),
                calcYValue(bgValues[currentPoint-1]))
            CGContextAddLineToPoint(context,
                calcXValue(currentPoint, xValuesCount: maxPoints),
                calcYValue(bgValues[currentPoint]))
        }
        CGContextStrokePath(context)
        
        // Drawing complete, retrieve the finished image and cleanup
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func adjustMinMaxYCoordinates(bgValues : [Int]) {
        for bgValue in bgValues {
            if bgValue < minimumYValue {
                minimumYValue = bgValue
            }
            if bgValue > maximumYValue {
                maximumYValue = bgValue
            }
        }
    }
    
    func calcXValue(x : Int, xValuesCount : Int) -> CGFloat {
        return CGFloat.init(canvasWidth / (xValuesCount-1) * x);
    }
    
    func calcYValue(y : Int) -> CGFloat {

        let calculatedY : Float = stretchedYValue(y)
        let mirroredY : Int = canvasHeight - Int(calculatedY)
        let cgfloat : CGFloat = CGFloat(mirroredY)
        
        return cgfloat
    }
    
    func stretchedYValue(y : Int) -> Float {
        return Float(canvasHeight) / Float(maximumYValue - minimumYValue) * Float(y - minimumYValue)
    }
}