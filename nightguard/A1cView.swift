//
//  A1cView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

class A1cView: BasicStatsControl {
    
    override var pages: [StatsPage] {
        return [
            StatsPage(segmentIndex: 0, name: "A1c", value: { [weak self] in
                CGFloat(self?.model?.a1c ?? 0)
                }, formatter: { "\(Float($0).cleanValue)%" }, color: .clear),
            StatsPage(segmentIndex: 1, name: "Average", value: { [weak self] in
                CGFloat(self?.model?.averageGlucose ?? 0)
                }, formatter: { UnitsConverter.toDisplayUnits("\($0)") + " \(UserDefaultsRepository.units.value.description)" },  color: .clear)
        ]
    }
    
    var a1cColor: UIColor? {
        
        guard let currentA1cValue = model?.a1c else {
            return nil
        }
        
        let bestA1cValue: CGFloat = 5.5
        let worstA1cValue: CGFloat = 8.5
        
        let power = max(min((worstA1cValue - CGFloat(currentA1cValue)) / (worstA1cValue - bestA1cValue), 1), 0)
        let color = UIColor(red: 1 - power, green: power, blue: 0, alpha: 1)
        
        print(color.debugDescription)
        
        return color
    }
    
    override func commonInit() {
        super.commonInit()
        
        diagramView.dataSource = self
    }
    
    override func modelWasSet() {
        super.modelWasSet()
        
        diagramView.backgroundColor = a1cColor?.withAlphaComponent(0.1)
    }
}

extension A1cView: SMDiagramViewDataSource {
    
    @objc func numberOfSegmentsIn(diagramView: SMDiagramView) -> Int {
        return 1
    }
    
    func diagramView(_ diagramView: SMDiagramView, colorForSegmentAtIndex index: NSInteger, angle: CGFloat) -> UIColor? {
        
        return a1cColor//.withAlphaComponent(0.2)
    }
    
    func diagramView(_ diagramView: SMDiagramView, radiusForSegmentAtIndex index: NSInteger, proportion: CGFloat, angle: CGFloat) -> CGFloat {
        return (diagramView.frame.size.height - 2/*diagramView.arcWidth*/) / 2
    }
    
    func diagramView(_ diagramView: SMDiagramView, lineWidthForSegmentAtIndex index: NSInteger, angle: CGFloat) -> CGFloat {
        //not called for SMDiagramViewModeSegment
        return 2.0
    }
}
