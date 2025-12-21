//
//  TouchReportingView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/21/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

/// UIButton or UITableViewCell like touch & tap detection UIControl, useful for giving a button behavior to any view (highlighting on touch, execute action on tap).
class TouchReportingView: UIControl {
    
    /// closure called when touch started (isHighlighted == true)
    var onTouchStarted: (() -> Void)?
    
    /// closure called when touch ended (isHighlighted == false)
    var onTouchEnded: (() -> Void)?
    
    /// closure called when a tap is detected
    var onTouchUpInside: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        addTarget(self, action: #selector(touchedUp), for: .touchUpInside)
        addTarget(self, action: #selector(touchedDown), for: .touchDown)
        addTarget(self, action:  #selector(exited), for: .touchCancel)
        addTarget(self, action:  #selector(exited), for: .touchDragExit)
        addTarget(self, action:  #selector(entered), for: .touchDragEnter)
    }
    
    @objc func touchedDown() {
        onTouchStarted?()
    }
    
    @objc func entered() {
        onTouchStarted?()
    }
    
    @objc func exited() {
        UIView.animate(withDuration: 0.4, animations: { [weak self] in
            self?.onTouchEnded?()
        })
    }
    
    @objc func touchedUp() {
        UIView.animate(withDuration: 0.4, animations: { [weak self] in
            self?.onTouchEnded?()
        })
        
        onTouchUpInside?()
    }
}
