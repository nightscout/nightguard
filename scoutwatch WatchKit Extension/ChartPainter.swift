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
    var maximumYValue = 200
    
    var canvasWidth : Int = 312
    var canvasHeight : Int = 120
    var size : CGSize
    
    init() {
        size = CGSize.init(width: canvasWidth, height: canvasHeight)
    }
    
    func drawImage(bgValues : [Int]) -> UIImage {
        // we need at least 2 values - otherwise paint nothing and return empty image!
        if bgValues.count <= 1 {
            return UIImage.init(named: "")!
        }
        
        // Setup our context
        let opaque = false
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
        let context = UIGraphicsGetCurrentContext()
        
        // Setup complete, do drawing here
        // Paint the part between 80 and 180 in gray
        CGContextSetLineWidth(context, 2.0)
        CGContextSetStrokeColorWithColor(context, UIColor.grayColor().CGColor)
        CGContextSetFillColorWithColor(context, UIColor.grayColor().CGColor)
        let goodPart = CGRect(origin: CGPoint.init(x: 0, y: calcYValue(180)), size: CGSize.init(width: canvasWidth, height: Int(stretchedYValue(100))))
        CGContextFillRect(context, goodPart)
        
        // Paint the glucose data
        CGContextSetStrokeColorWithColor(context, UIColor.greenColor().CGColor)
        CGContextBeginPath(context)
        
        let maxPoints : Int = bgValues.count
        for (var currentPoint = 1; currentPoint < maxPoints; currentPoint++) {
            
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
    
    private func calcXValue(x : Int, xValuesCount : Int) -> CGFloat {
        return CGFloat.init(canvasWidth / (xValuesCount-1) * x);
    }
    
    private func calcYValue(y : Int) -> CGFloat {
        var adjustedYValue = y;
        if adjustedYValue > maximumYValue {
            adjustedYValue = maximumYValue
        }
        let calculatedY : Float = stretchedYValue(adjustedYValue)
        let mirroredY : Int = canvasHeight - Int(calculatedY)
        return CGFloat.init(mirroredY)
    }
    
    private func stretchedYValue(y : Int) -> Float {
        return Float(canvasHeight) / Float(maximumYValue) * Float(y)
    }
}