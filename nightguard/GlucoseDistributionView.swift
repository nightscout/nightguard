//
//  GlucoseDistributionView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

class GlucoseDistributionView: BasicStatsControl {
    
    override func createPages() -> [StatsPage] {
        
        return [
            StatsPage(name: "In Range", value: model?.inRangeValuesPercentage, formattedValue: model?.formattedInRangeValuesPercentage, color: .green),
            StatsPage(name: "Low", value: model?.lowValuesPercentage, formattedValue: model?.formattedLowValuesPercentage, color: .red),
            StatsPage(name: "High", value: model?.highValuesPercentage, formattedValue: model?.formattedHighValuesPercentage, color: .yellow),
            StatsPage(name: "")
        ]
    }
    
    override func commonInit() {
        super.commonInit()
        
        diagramView.dataSource = self
    }
    
    override func pageChanged() {
        super.pageChanged()
        
        // display segments for last page
        diagramView.diagramViewMode = (currentPageIndex == (pages.count - 1)) ? .segment : .arc
    }
}

extension GlucoseDistributionView: SMDiagramViewDataSource {
    
    @objc func numberOfSegmentsIn(diagramView: SMDiagramView) -> Int {
        return pages.count - 1
    }
    
    func diagramView(_ diagramView: SMDiagramView, proportionForSegmentAtIndex index: NSInteger) -> CGFloat {
        guard let value = pages[index].value as? Float else {
            return 0
        }
        
        return CGFloat(value)
    }
    
    func diagramView(_ diagramView: SMDiagramView, colorForSegmentAtIndex index: NSInteger, angle: CGFloat) -> UIColor? {
        
        var color = pages[index].color
        
        //        if diagramView.diagramViewMode == .arc {
        if index != currentPageIndex {
            color = color?.withAlphaComponent(0.7)
        }
        //        }
        
        return color
    }
    
    func diagramView(_ diagramView: SMDiagramView, viewForSegmentAtIndex index: NSInteger, colorOfSegment color:UIColor?, angle: CGFloat) -> UIView? {
        
        if diagramView.diagramViewMode == .arc {
            return nil
        } else {
            guard let percentage = pages[index].value as? Float, percentage > 0.3 else {
                // not big enough!
                return nil
            }
            
            let percentsLabel = UILabel()
            percentsLabel.text = pages[index].formattedValue
            percentsLabel.textColor = UIColor.white.withAlphaComponent(0.7)
            percentsLabel.clipsToBounds = false
            percentsLabel.layer.shadowColor = UIColor.black.cgColor
            percentsLabel.layer.shadowOpacity = 1.0
            percentsLabel.layer.shadowOffset = CGSize(width: 2, height: 2)
            
            percentsLabel.font = UIFont.boldSystemFont(ofSize: 9)
            percentsLabel.sizeToFit()
            return percentsLabel
        }
    }
    
    func diagramView(_ diagramView: SMDiagramView, offsetForView view: UIView?, atIndex index: NSInteger, angle: CGFloat) -> CGPoint {
        return .zero
    }
    
    func diagramView(_ diagramView: SMDiagramView, radiusForView view: UIView?, atIndex index: NSInteger, radiusOfSegment radius: CGFloat, angle: CGFloat) -> CGFloat {
        return diagramView.frame.size.height / 4
    }
    
    func diagramView(_ diagramView: SMDiagramView, radiusForSegmentAtIndex index: NSInteger, proportion: CGFloat, angle: CGFloat) -> CGFloat {
        if diagramView.diagramViewMode == .arc {
            return (diagramView.frame.size.height - diagramView.arcWidth) / 2 + ((index == currentPageIndex) ? 0 : 1)
        } else {
            return diagramView.frame.size.height
        }
    }
    
    func diagramView(_ diagramView: SMDiagramView, lineWidthForSegmentAtIndex index: NSInteger, angle: CGFloat) -> CGFloat {
        //not called for SMDiagramViewModeSegment
        return (index == currentPageIndex) ? 8.0 : 6.0
    }
}
