//
//  BasicStatsControl.swift
//  nightguard
//
//  Created by Florian Preknya on 3/18/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

struct StatsPage {
    let segmentIndex: Int?
    let name: String?
    let value: (() -> CGFloat)?
    let formatter: ((CGFloat) -> String)?
    let color: UIColor?
    
    var formattedValue: String? {
        guard let value = self.value?() else { return nil}
        return formatter?(value)
    }
}

class BasicStatsControl: TouchReportingView {
    
    var model: BasicStats? {
        didSet {
            diagramView.reloadData()
            
            // reveal!
            UIView.animate(withDuration: 0.8) { [weak self] in
                self?.diagramView.alpha = 1
            }
            
            modelWasSet()
        }
    }
    
    var pages: [StatsPage] {
        
        // implement in subclasses
        return [
            StatsPage(segmentIndex: 0, name: nil, value: nil, formatter: nil, color: .clear)
        ]
    }
    
    var currentPageIndex: Int = 0 {
        didSet {
            pageChanged()
            diagramView.reloadData()
        }
    }
    
    var currentPage: StatsPage {
        return pages[currentPageIndex]
    }
    
    lazy var diagramView: SMDiagramView = createDiagramView()
    
    var valueLabel: UILabel? {
        return (diagramView.titleView as? UIStackView)?.arrangedSubviews.first as? UILabel
    }
    var nameLabel: UILabel? {
        return (diagramView.titleView as? UIStackView)?.arrangedSubviews.last as? UILabel
    }
    
    lazy var isSmallDevice: Bool = {
        return [.iPhone4, .iPhone5].contains( DeviceSize())
    }()
    
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
        
        // update title
        updateTitleView(name: currentPage.name, value: currentPage.formattedValue)
    }
    
    func pageChanged() {
        
        // update title
        updateTitleView(name: currentPage.name, value: currentPage.formattedValue)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layer.cornerRadius =  self.bounds.size.height / 2
    }
    
    func updateTitleView(name: String?, value: String?) {
        
        guard let titleView = diagramView.titleView else {
            return
        }
        
        nameLabel?.text = name
        valueLabel?.text = value
        
        titleView.bounds = CGRect(origin: CGPoint.zero, size: titleView.systemLayoutSizeFitting(UILayoutFittingCompressedSize))
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
        
        let valueLabel = UILabel()
        valueLabel.text = ""
        valueLabel.textAlignment = .center
        valueLabel.textColor = UIColor.white
        valueLabel.font = UIFont.boldSystemFont(ofSize: isSmallDevice ? 13 : 15)
        
        let nameLabel = UILabel()
        nameLabel.text = ""
        nameLabel.textAlignment = .center
        nameLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        nameLabel.font = UIFont.systemFont(ofSize: 9)
        
        let stackView = UIStackView(arrangedSubviews: [valueLabel, nameLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = isSmallDevice ? 2 : 4
        
        return stackView
    }
    
    func percent(_ value: CGFloat) -> String {
        return "\(Float(value * 100).cleanValue)%"
    }
}
