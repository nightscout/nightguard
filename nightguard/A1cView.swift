//
//  A1cView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

extension UIColor {
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

class A1cView: BasicStatsControl {
    
    override var pages: [StatsPage] {
        return [
            StatsPage(segmentIndex: 0, name: "A1c", value: { [weak self] in
                CGFloat(self?.model?.a1c ?? 0)
                }, formatter: { "\(Float($0).cleanValue)%" }, color: .clear),
            StatsPage(segmentIndex: 1, name: "Average", value: { [weak self] in
                CGFloat(self?.model?.averageGlucose ?? 0)
                }, formatter: { UnitsConverter.toDisplayUnits("\($0)") + "\n\(UserDefaultsRepository.units.value.description)" },  color: .clear),
            StatsPage(segmentIndex: 2, name: "Std Deviation", value: { [weak self] in
                CGFloat(self?.model?.standardDeviation ?? 0)
                }, formatter: { UnitsConverter.toDisplayUnits("\($0)") + "\n\(UserDefaultsRepository.units.value.description)" },  color: .clear),
            StatsPage(segmentIndex: 3, name: "Coefficient of Variation", value: { [weak self] in
                CGFloat(self?.model?.coefficientOfVariation ?? 0)
                }, formatter: percent,  color: .clear)
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
        return (currentPageIndex < 2) ? a1cColor : variationColor
    }
    
    override func commonInit() {
        super.commonInit()
        
        diagramView.dataSource = self
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
        return 1
    }

    func diagramView(_ diagramView: SMDiagramView, colorForSegmentAtIndex index: NSInteger, angle: CGFloat) -> UIColor? {
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
