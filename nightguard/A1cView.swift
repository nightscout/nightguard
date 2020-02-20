//
//  A1cView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

extension UIColor {
    
    // Creates a color-meter like UIColor by placing the given value in correspondence with its good-bad range, resulting a green color if the value is very good on that scale, a red color if is very bad or yellow & compositions with red-green if is in between
    static func redYellowGreen(for value: CGFloat, bestValue: CGFloat, worstValue: CGFloat) -> UIColor {
        if bestValue < worstValue {
            let power = max(min((worstValue - CGFloat(value)) / (worstValue - bestValue), 1), 0)
            return UIColor(red: 1 - power, green: power, blue: 0, alpha: 1)
        } else {
            let power = max(min((bestValue - CGFloat(value)) / (bestValue - worstValue), 1), 0)
            return UIColor(red: power, green: 1 - power, blue: 0, alpha: 1)
        }
    }
}

/**
 A stats view that displays the A1c value, the average BG value, standard deviation & variation values. It appreciates the values by giving a colored feedback to user: green - good values, yellow - okish, red - pretty bad.
 */
class A1cView: BasicStatsControl {
    
    override func createPages() -> [StatsPage] {
        return [
            StatsPage(name: NSLocalizedString("A1c", comment: "Button value for A1c"), formattedValue: model?.formattedA1c),
            StatsPage(name: NSLocalizedString("IFCC A1c", comment: "Button value for IFCC A1c"), formattedValue: model?.formattedIFCCA1c?.replacingOccurrences(of: " ", with: "\n")),
            StatsPage(name: NSLocalizedString("Average", comment: "Button value for Average"), formattedValue: model?.formattedAverageGlucose?.replacingOccurrences(of: " ", with: "\n")),
            StatsPage(name: NSLocalizedString("Std Deviation", comment: "Button value for Std Deviation"), formattedValue: model?.formattedStandardDeviation?.replacingOccurrences(of: " ", with: "\n")),
            StatsPage(name: NSLocalizedString("Coefficient of Variation", comment: "Button value for Coefficient of Variation"), formattedValue: model?.formattedCoefficientOfVariation)
        ]
    }
    
    fileprivate var a1cColor: UIColor? {
        
        guard let a1c = model?.a1c else {
            return nil
        }
        
        return UIColor.redYellowGreen(for: CGFloat(a1c), bestValue: 5.5, worstValue: 8.5)
    }
    
    fileprivate var variationColor: UIColor? {
        
        guard let coefficientOfVariation = model?.coefficientOfVariation else {
            return nil
        }
        
        return UIColor.redYellowGreen(for: CGFloat(coefficientOfVariation), bestValue: 0.3, worstValue: 0.5)
    }
    
    fileprivate var modelColor: UIColor? {
        return (currentPageIndex < 3) ? a1cColor : variationColor
    }
    
    override func commonInit() {
        super.commonInit()
        
        diagramView.dataSource = self
//        diagramView.separatorWidh = 8
//        diagramView.separatorColor = .black
//        diagramView.startAngle = .pi * 0.75
//        diagramView.endAngle = 2 * .pi + .pi * 0.75
        
        // cheating: extend the value label width (the mmol/mol units are too long)
        if let valueLabel = valueLabel {
            valueLabel.preferredMaxLayoutWidth += 8
        }
    }
    
    override func modelWasSet() {
        super.modelWasSet()
        diagramView.backgroundColor = modelColor?.withAlphaComponent(0.1)
    }
    
    override func pageChanged() {
        super.pageChanged()
        diagramView.backgroundColor = modelColor?.withAlphaComponent(0.1)
    }
}

extension A1cView: SMDiagramViewDataSource {
    
    @objc func numberOfSegmentsIn(diagramView: SMDiagramView) -> Int {
        return 2
    }

    func diagramView(_ diagramView: SMDiagramView, colorForSegmentAtIndex index: NSInteger, angle: CGFloat) -> UIColor? {
//        return (index == 1) ? a1cColor : variationColor
        return modelColor
    }
    
    func diagramView(_ diagramView: SMDiagramView, radiusForSegmentAtIndex index: NSInteger, proportion: CGFloat, angle: CGFloat) -> CGFloat {
        return (diagramView.frame.size.height - 2/*diagramView.arcWidth*/) / 2
    }
    
    func diagramView(_ diagramView: SMDiagramView, lineWidthForSegmentAtIndex index: NSInteger, angle: CGFloat) -> CGFloat {
        //not called for SMDiagramViewModeSegment
        return 2.0
    }
}
