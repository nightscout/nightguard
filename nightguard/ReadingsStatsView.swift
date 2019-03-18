//
//  ReadingsStatsView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

class ReadingsStatsView: BasicStatsControl {
    
    override var pages: [StatsPage] {
        return [
            StatsPage(segmentIndex: -1, name: "Readings", value: { [weak self] in
                CGFloat(self?.model?.readingsCount ?? 0)
                }, formatter: { [weak self] value in
                    "\(Float(value).cleanValue) / \(self?.model?.readingsMaximumCount ?? 0)"
                }, color: .clear),
            StatsPage(segmentIndex: 0, name: "Readings %", value: { [weak self] in
                CGFloat(self?.model?.readingsPercentage ?? 0)
                }, formatter: percent, color: .white)
        ]
    }
    
    override func commonInit() {
        super.commonInit()
        
        diagramView.dataSource = self
    }    
}

extension ReadingsStatsView: SMDiagramViewDataSource {
    
    @objc func numberOfSegmentsIn(diagramView: SMDiagramView) -> Int {
        return 1
    }
    
    func diagramView(_ diagramView: SMDiagramView, proportionForSegmentAtIndex index: NSInteger) -> CGFloat {
        return pages[index + 1].value?() ?? 0
    }
    
    func diagramView(_ diagramView: SMDiagramView, colorForSegmentAtIndex index: NSInteger, angle: CGFloat) -> UIColor? {
        
        return pages[index + 1].color?.withAlphaComponent(0.5)
    }
    
    func diagramView(_ diagramView: SMDiagramView, radiusForSegmentAtIndex index: NSInteger, proportion: CGFloat, angle: CGFloat) -> CGFloat {
        return (diagramView.frame.size.height - diagramView.arcWidth) / 2
    }
    
    func diagramView(_ diagramView: SMDiagramView, lineWidthForSegmentAtIndex index: NSInteger, angle: CGFloat) -> CGFloat {
        //not called for SMDiagramViewModeSegment
        return 6.0
    }
}
