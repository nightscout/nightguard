//
//  ChartScene.swift
//  nightguard
//
//  Created by Dirk Hermanns on 28.02.17.
//  Copyright © 2017 private. All rights reserved.
//

import Foundation
import SpriteKit

class ChartScene : SKScene {
    
    var chartNode = SKSpriteNode()
    var lastXTranslation : CGFloat = 0
    var canvasWidth : CGFloat = 0
    // Maximum right position of the chart
    var maxXPosition : CGFloat = 0
    // Minimum (left) position of the chart
    var minXPosition : CGFloat = 0
    var oldBloodSugarDays : [[BloodSugar]] = []
    // the maximum blood glucose value that will be displayed in the chart
    var maxYDisplayValue : CGFloat = 350
    
    init(size: CGSize, newCanvasWidth : CGFloat) {
        super.init(size: size)
        
        self.size = size
        self.backgroundColor = UIColor.black
        initialPlacingOfChart()
        
        paintChart([[], []], newCanvasWidth: newCanvasWidth, maxYDisplayValue: 350, moveToLatestValue: false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // maxYDisplayValue is the maximum Value that will be displayed in the chart.
    // Blood values that are higher will be set to maxYDisplayValue instead.
    func paintChart(_ days : [[BloodSugar]], newCanvasWidth : CGFloat, maxYDisplayValue : CGFloat, moveToLatestValue : Bool, displayDaysLegend : Bool) {

        //        let maxYDisplayValue : CGFloat = 250
        //        defaults.setFloat(Float(maxYDisplayValue), forKey: "maximumBloodGlucoseDisplayed")
        
        self.oldBloodSugarDays = days
        self.maxYDisplayValue = maxYDisplayValue
        self.canvasWidth = newCanvasWidth
        self.maxXPosition = 0
        self.minXPosition = size.width - canvasWidth
        
        let chartPainter : ChartPainter = ChartPainter(
            canvasWidth: Int(canvasWidth),
            canvasHeight: Int(size.height));
        
        let (upper, lower) = UserDefaultsRepository.readUpperLowerBounds()
        let (chartImage, displayPosition) = chartPainter.drawImage(
            days, maxBgValue: maxYDisplayValue,
            upperBoundNiceValue: upper,
            lowerBoundNiceValue: lower,
            displayDaysLegend: displayDaysLegend
        )
        
        if chartImage == nil {
            return
        }
        
        let chartTexture = SKTexture(image: chartImage!)
        let changeTextureAction : SKAction = SKAction.setTexture(chartTexture)
        self.chartNode.run(changeTextureAction)
        self.chartNode.size = chartImage!.size
        self.chartNode.zPosition = 1
        
        if moveToLatestValue {
            let newXPosition = normalizedXPosition(-CGFloat(displayPosition) + CGFloat(size.width * 2 / 3))
            let moveToNewValue = SKAction.move(
                to: CGPoint(x: newXPosition, y: 0),
                duration: 1)
            self.chartNode.run(moveToNewValue)
        }
    }
        
    // maxYDisplayValue is the maximum Value that will be displayed in the chart.
    // Blood values that are higher will be set to maxYDisplayValue instead.
    func paintChart(_ days : [[BloodSugar]], newCanvasWidth : CGFloat, maxYDisplayValue : CGFloat, moveToLatestValue : Bool) {

        paintChart(days, newCanvasWidth: newCanvasWidth, maxYDisplayValue: maxYDisplayValue, moveToLatestValue: moveToLatestValue, displayDaysLegend: true)
    }
    
    fileprivate func initialPlacingOfChart() {
        self.chartNode.anchorPoint = CGPoint(x: 0, y: 0)
        self.chartNode.position = CGPoint(x: 0, y: 0)
        
        self.removeAllChildren()
        self.insertChild(self.chartNode, at: 0)
        self.chartNode.zPosition = -1
    }
    
    fileprivate func boundLayerPos(_ aNewPosition: CGPoint) -> CGPoint {
        let winSize = self.size
        var retval = aNewPosition
        retval.x = CGFloat(min(retval.x, 0))
        retval.x = CGFloat(max(retval.x, -(chartNode.size.width) + winSize.width))
        retval.y = self.position.y
        
        return retval
    }
    
    func stopSwipeAction() {
        chartNode.removeAllActions()
    }
    
    func draggedByATouch(_ xtranslation : CGFloat) {
        
        moveXTranslationPosition(xtranslation)
    }
    
    func swipeChart(_ x : CGFloat) {
        
        let newXPosition = chartNode.position.x + CGFloat(x)
        if isTooMuchLeft(newXPosition) {
            let modifiedXPosition = -canvasWidth + size.width - 25
            let reducedSwipeAction = SKAction.move(to: CGPoint(x: modifiedXPosition, y: 0), duration: min(1, abs(Double((chartNode.position.x + canvasWidth + size.width + 25) / x))))
            wooberBackToRight(chartNode, action: reducedSwipeAction)
        } else if isTooMuchRight(newXPosition) {
            let reducedSwipeAction = SKAction.move(to: CGPoint(x: 0+25, y: 0), duration: abs(Double(chartNode.position.x / x)))
            wooberBackToLeft(chartNode, action: reducedSwipeAction)
        } else {
            let swipeAction = SKAction.moveBy(x: x, y: 0, duration: 1)
            swipeAction.timingMode = SKActionTimingMode.easeOut
            chartNode.run(swipeAction, withKey: "swipe")
        }
    }
    
    func moveChart(_ x : Double) {
        
        moveXTranslationPosition(CGFloat(x))
    }
    
    // Called when the user pinches the display. Used to scale the maximum blood glucose value up
    // or down. This effectively zoom in or out on the chart.
    func scale(_ scale : CGFloat, keepScale : Bool) {
        
        let oldValue = maxYDisplayValue
        var scaleUnequalZero = scale
        if (scaleUnequalZero == 0.0) {
            // take care to avoid a division by zero
            scaleUnequalZero = 0.01
        }
        let newMaxYDisplayValue = max(min(maxYDisplayValue * 1 / scaleUnequalZero, 400), 180)
        
        if newMaxYDisplayValue == oldValue {
            // scale is still the same -> nothing to do
            return
        }
        
        paintChart(oldBloodSugarDays, newCanvasWidth: canvasWidth, maxYDisplayValue: newMaxYDisplayValue, moveToLatestValue: false)
        
        if keepScale {
            
            UserDefaultsRepository.saveMaximumBloodGlucoseDisplayed(Float(newMaxYDisplayValue))
        } else {
            // restore the old value so that the next scale request is always
            // in relation to the original unscaled value
            // only after the pinch gesture ended, the new maxXDisplayValue is calculated.
            maxYDisplayValue = oldValue
        }
    }
    
    // Leaves the position as is - but the min or max Position if the 
    // chart would be outside of the screen
    fileprivate func normalizedXPosition(_ x : CGFloat) -> CGFloat {

        if isTooMuchLeft(x) {
            return minXPosition
        } else if isTooMuchRight(x) {
            return maxXPosition
        } else {
            return x
        }
    }
    
    fileprivate func moveXTranslationPosition(_ x : CGFloat) {
    
        let newXPosition = chartNode.position.x + CGFloat(x)
        chartNode.position = CGPoint(x: normalizedXPosition(newXPosition), y: chartNode.position.y)
    }
    
    fileprivate func isTooMuchLeft(_ newXPosition : CGFloat) -> Bool {
        return newXPosition < minXPosition
    }
    
    fileprivate func isTooMuchRight(_ newXPosition: CGFloat) -> Bool {
        return newXPosition > maxXPosition
    }
    
    fileprivate func wooberBackToRight(_ chartNode : SKNode, action : SKAction?) {
        let moveActionToLeft = SKAction.moveBy(x: 35, y: 0, duration: 0.2);
        let moveActionBackToMaxXPosition = SKAction.move(to: CGPoint(x: -canvasWidth + size.width, y: 0), duration: 0.2)
        
        chartNode.removeAllActions()
        var actions = [moveActionToLeft, moveActionBackToMaxXPosition]
        if action != nil {
            actions.insert(action!, at: 0)
        }
        chartNode.run(SKAction.sequence(actions))
    }
    
    fileprivate func wooberBackToLeft(_ chartNode : SKNode, action : SKAction?) {
        let moveActionToRight = SKAction.moveBy(x: -35, y: 0, duration: 0.2);
        let moveActionBackToMinXPosition = SKAction.move(to: CGPoint(x: 0, y: 0), duration: 0.2)
        moveActionBackToMinXPosition.timingMode = SKActionTimingMode.easeOut
        
        chartNode.removeAllActions()
        var actions = [moveActionToRight, moveActionBackToMinXPosition]
        if action != nil {
            actions.insert(action!, at: 0)
        }
        chartNode.run(SKAction.sequence(actions))
    }
}
