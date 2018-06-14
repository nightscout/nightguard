//
//  GroupedLabelsView.swift
//  nightguard
//
//  Created by Florian Preknya on 6/14/18.
//  Copyright © 2018 private. All rights reserved.
//

import UIKit

class GroupedLabelsView: UIStackView {
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        view.layer.cornerRadius = 3
        return view
    }()
    
    lazy var label: UILabel = {
        let label = PaddingLabel()
        label.insets = UIEdgeInsets(top: 0, left: 3, bottom: 0, right: 3)
        label.font = UIFont.systemFont(ofSize: 11)
        label.clipsToBounds = true
        return label
    }()
    
    lazy var highlightedLabel: UILabel = {
        let label = PaddingLabel()
        label.insets = UIEdgeInsets(top: 0, left: 3, bottom: 0, right: 3)
        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.clipsToBounds = true
        label.layer.cornerRadius = 3
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        
        layoutMargins = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        isLayoutMarginsRelativeArrangement = true
        
        //        spacing = 4
        
        pinBackground()
        addArrangedSubview(highlightedLabel)
        addArrangedSubview(label)
    }
    
    private func pinBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(backgroundView, at: 0)
        backgroundView.pin(to: self)
    }
}
