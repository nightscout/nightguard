//
//  BasicStatsControl.swift
//  nightguard
//
//  Created by Florian Preknya on 3/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

/**
 The stats page contains information about a statistic feature (name-value, other attributes used for drawing)
 */
struct StatsPage {
    var name: String
    var value: Any?
    var formattedValue: String?
    var detail: String?
    var color: UIColor?
    
    init(name: String, value: Any? = nil, formattedValue: String? = nil, detail: String? = nil, color: UIColor? = nil) {
        self.name = name
        self.value = value
        self.formattedValue = formattedValue
        self.detail = detail
        self.color = color
    }
}

/**
 The base stats view class, a round view that takes a BasicStats instance as model and displays a segment-like chart on margins (optional & very configurable) and property-value labels in the center (the curent stats page). The stats views can contain multiple pages; pages are turned when the user taps the view.
 */
class BasicStatsControl: TouchReportingView {
    
    var model: BasicStats? {
        didSet {
//            diagramView.reloadData()
            
            // reveal!
            UIView.animate(withDuration: 0.8) { [weak self] in
                self?.diagramView.alpha = 1
            }
            
            modelWasSet()
        }
    }
    
    var pages: [StatsPage] = []
    
    var currentPageIndex: Int = -1 {
        didSet {
            pageChanged()
            diagramView.reloadData()
        }
    }
    
    var currentPage: StatsPage? {
        guard currentPageIndex >= 0 && currentPageIndex < pages.count else {
            return nil
        }
        
        return pages[currentPageIndex]
    }
    
    lazy var diagramView: SMDiagramView = createDiagramView()
    
    var valueLabel: UILabel? {
        return (diagramView.titleView as? UIStackView)?.arrangedSubviews.first as? UILabel
    }
    var nameLabel: UILabel? {
        return (diagramView.titleView as? UIStackView)?.arrangedSubviews.last as? UILabel
    }
    
    fileprivate var alternateValueTimer: Timer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override func commonInit() {
        super.commonInit()
        
        clipsToBounds = true
        backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        
        onTouchStarted = { [unowned self] in
            self.diagramView.titleView?.alpha = 0.5
        }

        onTouchEnded = { [unowned self] in
            self.diagramView.titleView?.alpha = 1
        }
        
        onTouchUpInside = { [unowned self] in
            self.changePage()
        }

        // add to superview
        addSubview(diagramView)
        diagramView.pin(to: self)
        
        diagramView.titleView = createTitleView()
        diagramView.isUserInteractionEnabled = false
        
        let isSmallDevice = DeviceSize().isSmall
        nameLabel?.numberOfLines = 2
        nameLabel?.preferredMaxLayoutWidth = isSmallDevice ? 56 : 64
        valueLabel?.numberOfLines = 2
        valueLabel?.preferredMaxLayoutWidth = isSmallDevice ? 56 : 64

        
        // hidden until model is set
        diagramView.alpha = 0
    }
    
    func changePage() {
        if pages.count > 1 {
            self.currentPageIndex = (self.currentPageIndex + 1) % pages.count
        }
    }
    
    func modelWasSet() {
        
        // get current page name
        let currentPageName = currentPage?.name
        
        // recreate pages
        pages = createPages()
        
        // restore current page
        if pages.isEmpty {
            currentPageIndex = -1
        } else {
            if let currentPageName = currentPageName {
                currentPageIndex = pages.firstIndex(where: { $0.name == currentPageName }) ?? 0
            } else {
                currentPageIndex = 0
            }
        }
        
        // update title
        updateTitleView(name: currentPage?.name, value: currentPage?.formattedValue, detail: currentPage?.detail)
    }
    
    func createPages() -> [StatsPage] {
        
        // override in subclasses
        return [
            StatsPage(name: "")
        ]
    }
    
    func pageChanged() {
        
        // update title
        updateTitleView(name: currentPage?.name, value: currentPage?.formattedValue, detail: currentPage?.detail)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layer.cornerRadius =  self.bounds.size.height / 2
    }
    
    func updateTitleView(name: String?, value: String?, detail: String? = nil) {
        
        nameLabel?.text = name
        updateValueLabel(value)
        
        alternateValueTimer?.invalidate()
        alternateValueTimer = nil
        
        if detail != nil {
            
            alternateValueTimer = Timer.schedule(1.5) { [weak self] _ in
                guard let valueLabel = self?.valueLabel else { return }
                UIView.transition(with: valueLabel, duration: 0.4, options: .transitionFlipFromTop, animations: { [weak self] in
                    self?.updateValueLabel(detail, asDetail: true)
                })
                self?.updateTitleViewSize()
                
                self?.alternateValueTimer = Timer.schedule(1.5) { [weak self] _ in
                    UIView.transition(with: valueLabel, duration: 0.4, options: .transitionFlipFromBottom, animations: { [weak self] in
                        self?.updateValueLabel(value, asDetail: false)
                    })
                    self?.updateTitleViewSize()
                }
            }
        }
        
        updateTitleViewSize()
    }
    
    private func createDiagramView() -> SMDiagramView {
        
        let diagramView = SMDiagramView()
        diagramView.backgroundColor = .clear
        
        // configure
        diagramView.minProportion = 0.009
        diagramView.diagramViewMode = .arc // or .segment
        diagramView.diagramOffset = .zero
        diagramView.radiusOfSegments = 30.0
        //        diagramView.radiusOfViews = 50.0
        diagramView.arcWidth = 8.0 //Ignoring for SMtargetDiagramViewMode.segment
        diagramView.colorOfSegments = .clear
        //        targetDiagramView.viewsOffset = .zero
        diagramView.separatorWidh = 0.0
        diagramView.separatorColor = .clear
        
        return diagramView
    }
    
    private func createTitleView() -> UIView {

        let isSmallDevice = DeviceSize().isSmall

        let valueLabel = UILabel()
        valueLabel.text = ""
        valueLabel.textAlignment = .center
        valueLabel.textColor = UIColor.white
        valueLabel.font = UIFont.boldSystemFont(ofSize: isSmallDevice ? 13 : 15)
        
        let nameLabel = UILabel()
        nameLabel.text = ""
        nameLabel.textAlignment = .center
        nameLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        nameLabel.font = UIFont.systemFont(ofSize: isSmallDevice ? 8 : 9)
        
        let stackView = UIStackView(arrangedSubviews: [valueLabel, nameLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = isSmallDevice ? 2 : 4
        
        return stackView
    }
    
    func updateValueLabel(_ value: String?, asDetail: Bool = false) {
        
        guard let valueLabel = self.valueLabel else {
            return
        }
        
        let isSmallDevice = DeviceSize().isSmall
        
        valueLabel.text = value
        if asDetail {
            valueLabel.textColor = UIColor.white.withAlphaComponent(0.8)
            valueLabel.font = UIFont.systemFont(ofSize: isSmallDevice ? 13 : 15)
        } else {
            valueLabel.textColor = UIColor.white
            valueLabel.font = UIFont.boldSystemFont(ofSize: isSmallDevice ? 13 : 15)
        }
    }
    
    private func updateTitleViewSize() {
        guard let titleView = diagramView.titleView else {
            return
        }
        
        let width = self.bounds.width
        let height = titleView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        titleView.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: width, height: height))
    }
    
    func formattedDuration(fromReadingsCount readingsCount: Int) -> String {
        
        let totalMinutes = readingsCount * 5 // 5 minutes each reading
        
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours == 0 {
            return "\(minutes)m"
        } else if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}
