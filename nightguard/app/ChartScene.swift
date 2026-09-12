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
    var showYesterdaysBgs : Bool = true
    private(set) var latestXPosition: CGFloat?

    private let moveToLatestActionKey = "moveToLatestValue"

    // MARK: - Chart selection
    private let selectionTimeout: TimeInterval = 5
    private let treatmentSelectionTolerance: Double = 5 * 60 * 1000
    private var chartPainter: ChartPainter?
    private var selectionTimeoutWorkItem: DispatchWorkItem?
    private var selectionOverlay = SKNode()
    private(set) var isSelecting = false
    private(set) var selectedBloodSugar: BloodSugar?
    private(set) var selectedTreatments: [Treatment] = []
    var onSelectionTimeout: (() -> Void)?
    
    init(size: CGSize, newCanvasWidth : CGFloat, useContrastfulColors : Bool, showYesterdaysBgs : Bool) {
        
        super.init(size: size)

        self.size = size
        self.backgroundColor = UIColor.black
        self.showYesterdaysBgs = showYesterdaysBgs

        initialPlacingOfChart()
        
        paintChart([[], []], newCanvasWidth: newCanvasWidth, maxYDisplayValue: 350, moveToLatestValue: false, useContrastfulColors: useContrastfulColors, showYesterdaysBgs: showYesterdaysBgs)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // maxYDisplayValue is the maximum Value that will be displayed in the chart.
    // Blood values that are higher will be set to maxYDisplayValue instead.
    func paintChart(_ days : [[BloodSugar]], newCanvasWidth : CGFloat, maxYDisplayValue : CGFloat, moveToLatestValue : Bool,
                    displayDaysLegend : Bool, useConstrastfulColors : Bool, showYesterdaysBgs : Bool) {

        deactivateSelection()

        //        let maxYDisplayValue : CGFloat = 250
        //        defaults.setFloat(Float(maxYDisplayValue), forKey: "maximumBloodGlucoseDisplayed")
        
        self.oldBloodSugarDays = days
        self.maxYDisplayValue = maxYDisplayValue
        self.canvasWidth = newCanvasWidth
        self.maxXPosition = 0
        self.minXPosition = size.width - canvasWidth

        AppLogger.singleton.debug(
            "ChartScene: paint requested days=\(days.count) valueCounts=\(days.map(\.count)) scene=\(size.width)x\(size.height) canvasWidth=\(canvasWidth)",
            category: .nightscout
        )
        
        let chartPainter : ChartPainter = ChartPainter(
            canvasWidth: Int(canvasWidth),
            canvasHeight: Int(size.height));

        self.chartPainter = chartPainter
        
        let (chartImage, displayPosition) = chartPainter.drawImage(
            days, maxBgValue: maxYDisplayValue,
            upperBoundNiceValue: UserDefaultsRepository.upperBound.value,
            lowerBoundNiceValue: UserDefaultsRepository.lowerBound.value,
            displayDaysLegend: displayDaysLegend,
            showYesterdaysBGValues: showYesterdaysBgs,
            useContrastfulColors: useConstrastfulColors
        )
        
        // do nothing if the chart couldn't be created
        if chartImage == nil
            || ((chartImage?.size.width ?? 0) <= CGFloat(0))
            || ((chartImage?.size.height ?? 0) <= CGFloat(0)) {
            AppLogger.singleton.error(
                "ChartScene: ChartPainter returned no drawable image valueCounts=\(days.map(\.count)) scene=\(size.width)x\(size.height)",
                category: .nightscout
            )
            return
        }

        if chartImage?.size == CGSize(width: 10, height: 10) {
            AppLogger.singleton.warning(
                "ChartScene: ChartPainter returned its empty placeholder image valueCounts=\(days.map(\.count))",
                category: .nightscout
            )
        }

        // Clear any existing actions before applying new texture. The caller
        // can immediately re-apply the auto-follow policy after this repaint.
        self.chartNode.removeAllActions()

        let chartTexture = SKTexture(image: chartImage!)
        self.chartNode.texture = chartTexture  // Set directly instead of using action
        self.chartNode.size = chartImage!.size
        self.chartNode.zPosition = 1
        
        // Keep the latest target independent of the repaint. This lets the
        // watch return to the newest value after an inactivity timeout without
        // drawing the entire chart again.
        if displayPosition > 0 {
            latestXPosition = normalizedXPosition(-CGFloat(displayPosition) + CGFloat(size.width))
        } else {
            latestXPosition = nil
        }

        if moveToLatestValue {
            self.moveToLatestValue(animated: true)
        }
    }

    func moveToLatestValue(animated: Bool = true) {
        guard let latestXPosition else { return }

        chartNode.removeAction(forKey: moveToLatestActionKey)
        guard animated else {
            chartNode.position = CGPoint(x: latestXPosition, y: 0)
            return
        }

        let action = SKAction.move(
            to: CGPoint(x: latestXPosition, y: 0),
            duration: 1)
        chartNode.run(action, withKey: moveToLatestActionKey)
    }

    func stopMovingToLatestValue() {
        chartNode.removeAction(forKey: moveToLatestActionKey)
    }
        
    // maxYDisplayValue is the maximum Value that will be displayed in the chart.
    // Blood values that are higher will be set to maxYDisplayValue instead.
    func paintChart(_ days : [[BloodSugar]], newCanvasWidth : CGFloat, maxYDisplayValue : CGFloat, moveToLatestValue : Bool, useContrastfulColors : Bool, showYesterdaysBgs: Bool) {

        
        paintChart(days, newCanvasWidth: newCanvasWidth, maxYDisplayValue: maxYDisplayValue, moveToLatestValue: moveToLatestValue, displayDaysLegend: true, useConstrastfulColors: useContrastfulColors, showYesterdaysBgs: showYesterdaysBgs)
    }
    
    fileprivate func initialPlacingOfChart() {

        self.chartNode.anchorPoint = CGPoint(x: 0, y: 0)
        self.chartNode.position = CGPoint(x: 0, y: 0)

        self.removeAllChildren()
        self.insertChild(self.chartNode, at: 0)
        self.chartNode.zPosition = -1
        selectionOverlay.zPosition = 100
        self.addChild(selectionOverlay)
    }

    func reinitializeChart() {
        // Recreate the chartNode to fix any texture corruption
        self.chartNode.removeFromParent()
        self.chartNode = SKSpriteNode()
        initialPlacingOfChart()
    }

    // MARK: - Chart selection

    /// Toggles the iPhone selection mode. The x coordinate is in scene coordinates.
    func toggleSelection(atSceneX sceneX: CGFloat) {
        if isSelecting {
            deactivateSelection()
        } else {
            activateSelection(atSceneX: sceneX)
        }
    }

    /// Starts selection at the nearest glucose value to the supplied scene x coordinate.
    func activateSelection(atSceneX sceneX: CGFloat? = nil) {
        guard let painter = chartPainter else { return }
        let values = selectableBloodSugars
        guard !values.isEmpty else { return }

        let selected: BloodSugar
        if let sceneX {
            selected = values.min { lhs, rhs in
                abs(screenX(for: lhs, painter: painter) - sceneX) < abs(screenX(for: rhs, painter: painter) - sceneX)
            } ?? values[0]
        } else {
            selected = values.last ?? values[0]
        }

        isSelecting = true
        selectedBloodSugar = selected
        selectedTreatments = treatments(for: selected)
        redrawSelectionOverlay()
        restartSelectionTimeout()
    }

    func deactivateSelection() {
        selectionTimeoutWorkItem?.cancel()
        selectionTimeoutWorkItem = nil
        isSelecting = false
        selectedBloodSugar = nil
        selectedTreatments = []
        selectionOverlay.removeAllChildren()
    }

    /// Selects the nearest value while the user drags across the chart.
    func moveSelection(toSceneX sceneX: CGFloat) {
        guard isSelecting, let painter = chartPainter else { return }
        guard let selected = selectableBloodSugars.min(by: {
            abs(screenX(for: $0, painter: painter) - sceneX) < abs(screenX(for: $1, painter: painter) - sceneX)
        }) else { return }

        updateSelection(selected)
    }

    /// Moves one or more entries in the selection list. This is used by the Digital Crown.
    func moveSelection(by steps: Int) {
        let values = selectableBloodSugars
        guard !values.isEmpty else { return }

        if !isSelecting {
            activateSelection()
            return
        }

        guard let current = selectedBloodSugar,
              let currentIndex = values.firstIndex(where: { $0.timestamp == current.timestamp && $0.value == current.value }) else {
            activateSelection()
            return
        }

        let targetIndex = min(max(currentIndex + steps, 0), values.count - 1)
        updateSelection(values[targetIndex])
    }

    private var selectableBloodSugars: [BloodSugar] {
        // The previous-day overlay remains visible, but is never selectable.
        oldBloodSugarDays.first?.filter { value in
            value.isValid && value.date <= Date()
        } ?? []
    }

    private func updateSelection(_ value: BloodSugar) {
        selectedBloodSugar = value
        selectedTreatments = treatments(for: value)
        redrawSelectionOverlay()
        restartSelectionTimeout()
    }

    private func restartSelectionTimeout() {
        selectionTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.deactivateSelection()
            self.onSelectionTimeout?()
        }
        selectionTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + selectionTimeout, execute: workItem)
    }

    private func screenX(for value: BloodSugar, painter: ChartPainter) -> CGFloat {
        return chartNode.position.x + CGFloat(painter.stretchedXValue(value.timestamp))
    }

    private func treatments(for value: BloodSugar) -> [Treatment] {
        TreatmentsStream.singleton.treatments.filter {
            abs($0.timestamp - value.timestamp) <= treatmentSelectionTolerance
        }
    }

    private func redrawSelectionOverlay() {
        selectionOverlay.removeAllChildren()
        guard isSelecting,
              let value = selectedBloodSugar,
              let painter = chartPainter else { return }

        let x = screenX(for: value, painter: painter)
        // ChartPainter draws in a top-left coordinate system, while SpriteKit
        // positions overlay nodes in a bottom-left coordinate system.
        let y = size.height - painter.calcYValue(value.value)
        let lineColor = UIColor.white.withAlphaComponent(0.8)

        let verticalLine = SKShapeNode(rectOf: CGSize(width: 1, height: size.height))
        verticalLine.position = CGPoint(x: x, y: size.height / 2)
        verticalLine.fillColor = lineColor
        verticalLine.strokeColor = .clear
        selectionOverlay.addChild(verticalLine)

        let horizontalLine = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
        horizontalLine.position = CGPoint(x: size.width / 2, y: y)
        horizontalLine.fillColor = lineColor
        horizontalLine.strokeColor = .clear
        selectionOverlay.addChild(horizontalLine)

        let point = SKShapeNode(circleOfRadius: size.height < 400 ? 4 : 6)
        point.position = CGPoint(x: x, y: y)
        point.fillColor = UIColor.nightguardGreen()
        point.strokeColor = .white
        point.lineWidth = 1
        selectionOverlay.addChild(point)

        let valueLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        valueLabel.text = UnitsConverter.mgdlToDisplayUnits(value.value.cleanValue)
        valueLabel.fontSize = size.height < 400 ? 14 : 22
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = x > size.width * 0.65 ? .right : .left
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: x + (valueLabel.horizontalAlignmentMode == .right ? -6 : 6), y: labelY(for: y, offset: 22))
        selectionOverlay.addChild(valueLabel)

        let timeLabel = SKLabelNode(fontNamed: "Helvetica")
        timeLabel.text = selectionTimeFormatter.string(from: value.date)
        timeLabel.fontSize = size.height < 400 ? 10 : 14
        timeLabel.fontColor = .white
        timeLabel.horizontalAlignmentMode = valueLabel.horizontalAlignmentMode
        timeLabel.verticalAlignmentMode = .center
        timeLabel.position = CGPoint(x: valueLabel.position.x, y: labelY(for: y, offset: 38))
        selectionOverlay.addChild(timeLabel)

        if !selectedTreatments.isEmpty {
            let treatmentLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
            treatmentLabel.text = selectedTreatments.map(treatmentText).joined(separator: "  ")
            treatmentLabel.fontSize = size.height < 400 ? 12 : 18
            treatmentLabel.fontColor = UIColor.nightguardYellow()
            treatmentLabel.horizontalAlignmentMode = valueLabel.horizontalAlignmentMode
            treatmentLabel.verticalAlignmentMode = .center
            treatmentLabel.position = CGPoint(x: valueLabel.position.x, y: labelY(for: y, offset: 58))
            selectionOverlay.addChild(treatmentLabel)

            for treatment in selectedTreatments {
                let treatmentPoint = SKShapeNode(circleOfRadius: size.height < 400 ? 6 : 9)
                treatmentPoint.position = CGPoint(
                    x: chartNode.position.x + CGFloat(painter.stretchedXValue(treatment.timestamp)),
                    y: y)
                treatmentPoint.fillColor = .clear
                treatmentPoint.strokeColor = UIColor.nightguardYellow()
                treatmentPoint.lineWidth = size.height < 400 ? 2 : 3
                selectionOverlay.addChild(treatmentPoint)
            }
        }
    }

    private func labelY(for chartY: CGFloat, offset: CGFloat) -> CGFloat {
        if chartY > size.height * 0.65 {
            return max(12, chartY - offset)
        }
        return min(size.height - 12, chartY + offset)
    }

    private lazy var selectionTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()

    private func treatmentText(_ treatment: Treatment) -> String {
        if let meal = treatment as? MealBolusTreatment {
            return treatmentAmount(carbs: meal.carbs, insulin: meal.insulin)
        }
        if let correction = treatment as? CorrectionBolusTreatment {
            return String(format: NSLocalizedString("Bolus %.1fU", comment: "Selected correction bolus"), correction.insulin)
        }
        if let wizard = treatment as? BolusWizardTreatment {
            return String(format: NSLocalizedString("Bolus %.1fU", comment: "Selected bolus wizard treatment"), wizard.insulin)
        }
        if let carbs = treatment as? CarbCorrectionTreatment {
            return String(format: NSLocalizedString("Carbs %dg", comment: "Selected carb treatment"), carbs.carbs)
        }
        return ""
    }

    private func treatmentAmount(carbs: Int, insulin: Double) -> String {
        var result = carbs > 0 ? "\(carbs)g" : ""
        if insulin > 0 {
            if !result.isEmpty { result += "/" }
            result += String(format: "%.1fU", insulin)
        }
        return result
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
        
        paintChart(oldBloodSugarDays, newCanvasWidth: canvasWidth, maxYDisplayValue: newMaxYDisplayValue, moveToLatestValue: false, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: self.showYesterdaysBgs)
        
        if keepScale {
            
            UserDefaultsRepository.maximumBloodGlucoseDisplayed.value = Float(newMaxYDisplayValue)
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
        stopMovingToLatestValue()
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
