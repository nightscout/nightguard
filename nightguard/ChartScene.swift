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
    
    override init(size: CGSize) {
        super.init(size: size)
        
        self.size = size
        initialPlacingOfChart()
        
        paintChart([], yesterdayValues: [])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func paintChart(bgValues : [BloodSugar], yesterdayValues : [BloodSugar]) {
        
        let canvasWidth = Int(size.width * 6)
        let chartPainter : ChartPainter = ChartPainter(
            canvasWidth: canvasWidth,
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
        self.chartNode.position = CGPointMake(-CGFloat(displayPosition) + CGFloat(size.width * 2 / 3), 0)
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
    
    private func panForTranslation(translation: CGPoint) {
        
        let aNewPosition = CGPoint(x: chartNode.position.x + translation.x, y: chartNode.position.y)
        chartNode.position = aNewPosition
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch: AnyObject in touches {
            let positionInScene = touch.locationInNode(self)
            let previousPosition = touch.previousLocationInNode(self)
            lastXTranslation = positionInScene.x - previousPosition.x
            let translation = CGPoint(x: lastXTranslation, y: positionInScene.y - previousPosition.y)
            
            panForTranslation(translation)
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        chartNode.removeAllActions()
        lastXTranslation = 0
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        let moveAction = SKAction.moveByX(lastXTranslation * 20, y: 0, duration: abs(Double(lastXTranslation) / 10));
        moveAction.timingMode = SKActionTimingMode.EaseOut
        
        chartNode.runAction(moveAction)
    }
}
