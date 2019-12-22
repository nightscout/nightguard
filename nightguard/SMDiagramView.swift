//
//  SMDiagramView.swift
//  SMDiagramView
//
//  Created by OLEKSANDR SEMENIUK on 12/1/17.
//  Copyright © 2017 OLEKSANDR SEMENIUK. All rights reserved.
//

import UIKit

@objc public protocol SMDiagramViewDataSource: class {
    
    @objc func numberOfSegmentsIn(diagramView: SMDiagramView) -> Int
    
    @objc optional func diagramView(_ diagramView: SMDiagramView, proportionForSegmentAtIndex index: NSInteger) -> CGFloat
    @objc optional func diagramView(_ diagramView: SMDiagramView, colorForSegmentAtIndex index: NSInteger, angle: CGFloat) -> UIColor?
    @objc optional func diagramView(_ diagramView: SMDiagramView, viewForSegmentAtIndex index: NSInteger, colorOfSegment color:UIColor?, angle: CGFloat) -> UIView?
    @objc optional func diagramView(_ diagramView: SMDiagramView, offsetForView view: UIView?, atIndex index: NSInteger, angle: CGFloat) -> CGPoint
    @objc optional func diagramView(_ diagramView: SMDiagramView, radiusForView view: UIView?, atIndex index: NSInteger, radiusOfSegment radius: CGFloat, angle: CGFloat) -> CGFloat
    @objc optional func diagramView(_ diagramView: SMDiagramView, radiusForSegmentAtIndex index: NSInteger, proportion: CGFloat, angle: CGFloat) -> CGFloat
    @objc optional func diagramView(_ diagramView: SMDiagramView, lineWidthForSegmentAtIndex index: NSInteger, angle: CGFloat) -> CGFloat //not called for SMDiagramViewModeSegment
}

@objc public enum SMDiagramViewMode: Int
{
    case arc, segment
}

@objc public class SMDiagramView: UIView
{
    private var models = [SMDiagramViewModel]()
    
    public var dataSource: SMDiagramViewDataSource?
    
    private var _emptyView: UIView?
    
    public var emptyView: UIView?
    {
        get
        {
            return _emptyView
        }
        set
        {
            _emptyView?.removeFromSuperview()
            _emptyView = newValue
            if let view = _emptyView
            {
                addSubview(view)
            }
            layoutIfNeeded()
        }
    }
    
    private var _titleView: UIView?
    
    public var titleView: UIView?
    {
        get
        {
            return _titleView
        }
        set
        {
            _titleView?.removeFromSuperview()
            _titleView = newValue
            if let view = _titleView
            {
                addSubview(view)
            }
            layoutIfNeeded()
        }
    }
    
    public var minProportion: CGFloat = 0.1
    public var diagramViewMode: SMDiagramViewMode = .arc
    public var diagramOffset: CGPoint = .zero
    public var radiusOfSegments: CGFloat = 80.0
    public var radiusOfViews: CGFloat = 130.0
    public var arcWidth: CGFloat = 6.0 //Ignoring for SMDiagramViewMode.segment
    public var startAngle: CGFloat = -.pi/2
    public var endAngle: CGFloat = 2.0 * .pi - .pi/2.0
    public var colorOfSegments: UIColor = .black
    public var viewsOffset: CGPoint = .zero
    public var separatorWidh: CGFloat = 1.0
    private var _separatorColor: UIColor
    {
        get
        {
            if let color = separatorColor
            {
                return color
            }
            if let color = backgroundColor
            {
                return color
            }
            return UIColor.white
        }
    }
    public var separatorColor: UIColor?
    
    private var centerOfCircle: CGPoint
    {
        get
        {
            return CGPoint(x: frame.size.width/2.0 + diagramOffset.x, y: frame.size.height/2.0 + diagramOffset.y)
        }
    }
    
    override public func draw(_ rect: CGRect)
    {
        super.draw(rect)
        
        drawDiagram()
    }
    
    override public func layoutSubviews()
    {
        super.layoutSubviews()
        
        updateViewsPositions()
    }
    
    private func drawDiagram()
    {
        for model in models
        {
            if let c = UIGraphicsGetCurrentContext()
            {
                c.addArc(center: centerOfCircle, radius: model.radiusOfSegment, startAngle: model.startAngle, endAngle: model.endAngle, clockwise: false)
                c.setLineWidth(model.lineWidth)
                if let color = model.color
                {
                    c.setStrokeColor(color.cgColor)
                }
                c.drawPath(using: .stroke)
            }
        }
        
        if diagramViewMode == .arc
        {
            drawSeparator()
        }
    }
    
    private func drawSeparator()
    {
        if models.count < 2
        {
            return
        }
        
        for model in models
        {
            if let c = UIGraphicsGetCurrentContext()
            {
                c.addArc(center: centerOfCircle, radius: model.radiusOfSegment, startAngle: model.separatorStartAngle, endAngle: model.separatorEndAngle, clockwise: false)
                c.setLineWidth(model.separatorLineWidth)
                c.setStrokeColor(_separatorColor.cgColor)
                c.drawPath(using: .stroke)
            }
        }
    }
    
    private func removeViews()
    {
        for model in models
        {
            if let view = model.view
            {
                view.removeFromSuperview()
            }
        }
        
        hideEmptyView()
    }
    
    private func updateViewsPositions()
    {
        for model in models
        {
            if let view = model.view
            {
                view.center = CGPoint(x: centerOfCircle.x + model.viewPosition.x, y: centerOfCircle.y + model.viewPosition.y)
            }
        }
        
        titleView?.center = centerOfCircle
    }
    
    private func showEmptyView()
    {
        if let view = emptyView
        {
            bringSubviewToFront(view)
            view.alpha = 1.0
            view.isHidden = false
        }
    }
    
    private func hideEmptyView()
    {
        if let view = emptyView
        {
            view.alpha = 0.0
            view.isHidden = true
        }
    }
    
    private func updateProportions()
    {
        var additionalSum: CGFloat = 0.0
        var lessSum: CGFloat = 0.0
        var sum: CGFloat = 0.0
        
        for model in models
        {
            sum += model.calculatedProportion
            
            if model.calculatedProportion < minProportion
            {
                lessSum += model.calculatedProportion
                additionalSum += minProportion - model.calculatedProportion
                model.calculatedProportion = minProportion
            }
        }
        
        if additionalSum == 0.0
        {
            return
        }
        
        let greatSum = sum - lessSum
        
        for model in models
        {
            if model.calculatedProportion > minProportion
            {
                model.calculatedProportion -= (model.calculatedProportion / greatSum) * additionalSum
            }
        }
        
        updateProportions()
    }
    
    public func reloadData()
    {
        removeViews()
        
        models.removeAll()
        
        let count = dataSource?.numberOfSegmentsIn(diagramView: self)
        
        if endAngle > startAngle
        {
            if let count = count, count > 0
            {
                let originalProportion: CGFloat = 1.0/CGFloat(count)
                
                assert(CGFloat(roundf(Float(originalProportion*100))/100) >= minProportion, "SMDiagramView. 1/count should not be less minProportion\ncount = \(count)\nminProportion = \(minProportion)")

                var result = [SMDiagramViewModel]()
                var totalProportion: CGFloat = 0.0
                
                for i in 0 ..< count {
                    let model = SMDiagramViewModel()
                    model.originalProportion = dataSource?.diagramView?(self, proportionForSegmentAtIndex: i) ?? originalProportion
                    
                    totalProportion += model.originalProportion
                    
                    assert(roundf(Float(totalProportion*100))/100 <= 1.0 && totalProportion >= 0.0, "SMDiagramView. Sum of proportions = \(totalProportion) must be less or equal 1.0 or equal 0.0")
                    
                    model.calculatedProportion = model.originalProportion
                    
                    result.append(model)
                }
                
                models = result
                
                updateProportions()
                var tempStartAngle = startAngle
                
                for i in 0 ..< count
                {
                    let model = models[i]
                    
                    model.startAngle = tempStartAngle
                    model.angleStep = (endAngle - startAngle)*model.calculatedProportion
                    
                    model.color = dataSource?.diagramView?(self, colorForSegmentAtIndex: i, angle: model.angle) ?? colorOfSegments
                    if let view = dataSource?.diagramView?(self, viewForSegmentAtIndex: i, colorOfSegment: model.color, angle: model.angle)
                    {
                        self.addSubview(view)
                        model.view = view
                    }
                    model.radiusOfSegment = dataSource?.diagramView?(self, radiusForSegmentAtIndex: i, proportion: model.calculatedProportion, angle: model.angle) ?? radiusOfSegments
                    model.radiusOfView = dataSource?.diagramView?(self, radiusForView: model.view, atIndex: i, radiusOfSegment: model.radiusOfSegment, angle: model.angle) ?? radiusOfViews
                    model.viewOffset = dataSource?.diagramView?(self, offsetForView: model.view, atIndex: i, angle: model.angle) ?? viewsOffset
                    model.lineWidth = dataSource?.diagramView?(self, lineWidthForSegmentAtIndex: i, angle: model.angle) ?? arcWidth
                    
                    model.separatorWidh = separatorWidh
                    model.diagramViewMode = diagramViewMode
                    tempStartAngle = model.endAngle
                }
            } else
            {
                showEmptyView()
            }
        }
        
        layoutIfNeeded()
        setNeedsDisplay()
    }
    
}

fileprivate class SMDiagramViewModel
{
    var view: UIView?
    var color: UIColor?
    var angleStep: CGFloat = 0.0
    var calculatedProportion: CGFloat = 0.0
    var originalProportion: CGFloat = 0.0
    var startAngle: CGFloat = 0.0
    private var _radiusOfSegment: CGFloat = 0.0
    private var _lineWidth: CGFloat = 0.0
    var radiusOfView: CGFloat = 0.0
    var viewOffset: CGPoint = .zero
    var separatorWidh: CGFloat = 0.0
    var diagramViewMode: SMDiagramViewMode = .arc
    
    var radiusOfSegment: CGFloat
    {
        set
        {
            _radiusOfSegment = newValue
        }
        
        get
        {
            switch diagramViewMode {
            case .arc:
                return _radiusOfSegment
            case .segment:
                return _radiusOfSegment/2.0
            }
        }
    }
    
    var lineWidth: CGFloat
    {
        set
        {
            _lineWidth = newValue
        }
        
        get
        {
            switch diagramViewMode {
            case .arc:
                return _lineWidth
            case .segment:
                return _radiusOfSegment
            }
        }
    }
    
    var endAngle: CGFloat
    {
        get
        {
            return startAngle + angleStep
        }
    }
    
    var angle: CGFloat
    {
        get
        {
            return endAngle - angleStep/2.0
        }
    }
    
    var viewPosition: CGPoint
    {
        get
        {
            return CGPoint(x: xPosition, y: yPosition)
        }
    }
    
    private var xPosition: CGFloat
    {
        get
        {
            return CGFloat(cosf(Float(endAngle - angleStep/2.0))) * radiusOfView + viewOffset.x
        }
    }
    
    private var yPosition: CGFloat
    {
        get
        {
            return CGFloat(sinf(Float(endAngle - angleStep/2.0))) * radiusOfView + viewOffset.y
        }
    }
    
    var separatorStartAngle: CGFloat
    {
        get
        {
            return endAngle - separatorAngleStep/2.0
        }
    }
    
    var separatorEndAngle: CGFloat
    {
        get
        {
            return endAngle + separatorAngleStep/2.0
        }
    }
    
    var separatorAngleStep: CGFloat
    {
        get
        {
            return separatorWidh/radiusOfSegment
        }
    }
    
    var separatorLineWidth: CGFloat
    {
        get
        {
            return lineWidth + 2.0 / UIScreen.main.scale
        }
    }
}
