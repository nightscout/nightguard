//
//  GlucoseDistributionView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

class GlucoseDistributionView: BasicStatsControl {
    
    override var pages: [StatsPage] {
        return [
            StatsPage(segmentIndex: 1, name: "In Range", value: { [weak self] in
                CGFloat(self?.model?.inRangeValuesPercentage ?? 0)
                }, formatter: percent, color: .green),
            StatsPage(segmentIndex: 0, name: "Low", value: { [weak self] in
                CGFloat(self?.model?.lowValuesPercentage ?? 0)
                }, formatter: percent, color: .red),
            StatsPage(segmentIndex: 2, name: "High", value: { [weak self] in
                CGFloat(self?.model?.highValuesPercentage ?? 0)
                }, formatter: percent, color: .yellow),
            StatsPage(segmentIndex: nil, name: nil, value: nil, formatter: nil, color: nil)
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
        return 3
    }
    
    func diagramView(_ diagramView: SMDiagramView, proportionForSegmentAtIndex index: NSInteger) -> CGFloat {
        return pages[index].value?() ?? 0
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
            guard let percentage = pages[index].value?(), percentage > 0.3 else {
                // not big enough!
                return nil
            }
            
            let percentsLabel = UILabel()
            percentsLabel.text = percent(percentage)
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
