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
    
    override init(size: CGSize) {
        super.init(size: size)
        
        self.size = size
        self.backgroundColor = UIColor.blackColor()
        initialPlacingOfChart()
        
        paintChart([], yesterdayValues: [])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func paintChart(bgValues : [BloodSugar], yesterdayValues : [BloodSugar]) {
        
        canvasWidth = CGFloat(size.width * 6)
        maxXPosition = 0
        minXPosition = size.width - canvasWidth
        
        let chartPainter : ChartPainter = ChartPainter(
            canvasWidth: Int(canvasWidth),
            canvasHeight: Int(size.height));
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        guard case let (chartImage?, displayPosition) = chartPainter.drawImage(
            [UnitsConverter.toDisplayUnits(bgValues), UnitsConverter.toDisplayUnits(yesterdayValues)],
            upperBoundNiceValue: UnitsConverter.toDisplayUnits(defaults!.floatForKey("alertIfAboveValue")),
            lowerBoundNiceValue: UnitsConverter.toDisplayUnits(defaults!.floatForKey("alertIfBelowValue"))
        ) else {
            return
        }
        
        let chartTexture = SKTexture(image: chartImage)
        self.chartNode.texture = chartTexture
        self.chartNode.size = chartImage.size
        
        let moveToNewValue = SKAction.moveTo(
            CGPointMake(
                normalizedXPosition(-CGFloat(displayPosition) + CGFloat(size.width * 2 / 3)),
                0), duration: 1)
        self.chartNode.runAction(moveToNewValue)
    }
    
    private func initialPlacingOfChart() {
        self.chartNode.anchorPoint = CGPointMake(0, 0)
        self.chartNode.position = CGPointMake(0, 0)
        
        self.removeAllChildren()
        self.insertChild(self.chartNode, atIndex: 0)
        self.chartNode.zPosition = -1
    }
    
    private func boundLayerPos(aNewPosition: CGPoint) -> CGPoint {
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
    
    func draggedByATouch(xtranslation : CGFloat) {
        
        moveXTranslationPosition(xtranslation)
    }
    
    func swipeChart(x : CGFloat) {
        
        let newXPosition = chartNode.position.x + CGFloat(x)
        if isTooMuchLeft(newXPosition) {
            let modifiedXPosition = -canvasWidth + size.width - 25
            let reducedSwipeAction = SKAction.moveTo(CGPoint(x: modifiedXPosition, y: 0), duration: min(1, abs(Double((chartNode.position.x + canvasWidth + size.width + 25) / x))))
            wooberBackToRight(chartNode, action: reducedSwipeAction)
        } else if isTooMuchRight(newXPosition) {
            let reducedSwipeAction = SKAction.moveTo(CGPoint(x: 0+25, y: 0), duration: abs(Double(chartNode.position.x / x)))
            wooberBackToLeft(chartNode, action: reducedSwipeAction)
        } else {
            let swipeAction = SKAction.moveByX(x, y: 0, duration: 1)
            swipeAction.timingMode = SKActionTimingMode.EaseOut
            chartNode.runAction(swipeAction, withKey: "swipe")
        }
    }
    
    func moveChart(x : Double) {
        
        moveXTranslationPosition(CGFloat(x))
    }
    
    // Leaves the position as is - but the min or max Position if the 
    // chart would be outside of the screen
    private func normalizedXPosition(x : CGFloat) -> CGFloat {

        if isTooMuchLeft(x) {
            return minXPosition
        } else if isTooMuchRight(x) {
            return maxXPosition
        } else {
            return x
        }
    }
    
    private func moveXTranslationPosition(x : CGFloat) {
    
        let newXPosition = chartNode.position.x + CGFloat(x)
        chartNode.position = CGPoint(x: normalizedXPosition(newXPosition), y: chartNode.position.y)
    }
    
    private func isTooMuchLeft(newXPosition : CGFloat) -> Bool {
        return newXPosition < minXPosition
    }
    
    private func isTooMuchRight(newXPosition: CGFloat) -> Bool {
        return newXPosition > maxXPosition
    }
    
    private func wooberBackToRight(chartNode : SKNode, action : SKAction?) {
        let moveActionToLeft = SKAction.moveByX(35, y: 0, duration: 0.2);
        let moveActionBackToMaxXPosition = SKAction.moveTo(CGPoint(x: -canvasWidth + size.width, y: 0), duration: 0.2)
        
        chartNode.removeAllActions()
        var actions = [moveActionToLeft, moveActionBackToMaxXPosition]
        if action != nil {
            actions.insert(action!, atIndex: 0)
        }
        chartNode.runAction(SKAction.sequence(actions))
    }
    
    private func wooberBackToLeft(chartNode : SKNode, action : SKAction?) {
        let moveActionToRight = SKAction.moveByX(-35, y: 0, duration: 0.2);
        let moveActionBackToMinXPosition = SKAction.moveTo(CGPoint(x: 0, y: 0), duration: 0.2)
        moveActionBackToMinXPosition.timingMode = SKActionTimingMode.EaseOut
        
        chartNode.removeAllActions()
        var actions = [moveActionToRight, moveActionBackToMinXPosition]
        if action != nil {
            actions.insert(action!, atIndex: 0)
        }
        chartNode.runAction(SKAction.sequence(actions))
    }
}
