//
//  ReadingsStatsView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

/**
 The stats view that displays the number of readings in the selected stats period, how many were invalid, etc.
 */
class ReadingsStatsView: BasicStatsControl {
    
    override func createPages() -> [StatsPage] {
        
        let invalidValuesPercentage = model?.invalidValuesPercentage ?? 0
        let readingsPercent = (model?.readingsPercentage ?? 0) - invalidValuesPercentage
        var pages = [
            StatsPage(name: NSLocalizedString("Readings", comment: "Text of Readings stats button"), formattedValue: "\(Float(model?.readingsCount ?? 0).cleanValue) / \(model?.readingsMaximumCount ?? 0)"),
            StatsPage(name: NSLocalizedString("Readings %", comment: "Text of Reading% stats button"), value: readingsPercent, formattedValue: model?.formattedReadingsPercentage, color: .white)
        ]
        
        if let invalidValuesCount = model?.invalidValuesCount, invalidValuesCount > 0 {
            
            pages.append(
                StatsPage(name: NSLocalizedString("Invalid readings", comment: "Invalid readings"), value: invalidValuesPercentage, formattedValue: "\(invalidValuesCount)", detail: formattedDuration(fromReadingsCount: invalidValuesCount) ,color: .red)
            )
        }
        
        return pages
    }
    
    override func commonInit() {
        super.commonInit()
        
        diagramView.dataSource = self
    }    
}

extension ReadingsStatsView: SMDiagramViewDataSource {
    
    @objc func numberOfSegmentsIn(diagramView: SMDiagramView) -> Int {
        return pages.count - 1
    }
    
    func diagramView(_ diagramView: SMDiagramView, proportionForSegmentAtIndex index: NSInteger) -> CGFloat {
        guard let value = pages[index + 1].value as? Float else {
            return 0
        }
        
        return CGFloat(value)
    }
    
    func diagramView(_ diagramView: SMDiagramView, colorForSegmentAtIndex index: NSInteger, angle: CGFloat) -> UIColor? {
        let color = pages[index + 1].color
        return (index == 0 || currentPageIndex < 2) ? color?.withAlphaComponent(0.5) : color
    }
    
    func diagramView(_ diagramView: SMDiagramView, radiusForSegmentAtIndex index: NSInteger, proportion: CGFloat, angle: CGFloat) -> CGFloat {
        return (diagramView.frame.size.height - diagramView.arcWidth) / 2
    }
    
    func diagramView(_ diagramView: SMDiagramView, lineWidthForSegmentAtIndex index: NSInteger, angle: CGFloat) -> CGFloat {
        //not called for SMDiagramViewModeSegment
        return 6.0
    }
}
