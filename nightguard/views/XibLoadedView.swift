//
//  XibLoadedView.swift
//  nightguard
//
//  Created by Florian Preknya on 3/12/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

class XibLoadedView: UIView {
    
    // the custom view from the XIB file
    var view: UIView!
    
    // the XIB file name (by default, the class name - override this property in subclasses if needed)
    var nibName: String {
        return NSStringFromClass(type(of: self)).components(separatedBy: ".").last!
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        xibSetup()
    }
    
    fileprivate func xibSetup() {
        self.backgroundColor = .clear
        view = loadViewFromNib()
        
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            view.topAnchor.constraint(equalTo: self.topAnchor),
            view.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    fileprivate func loadViewFromNib() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nibName = self.nibName
        guard let _ = bundle.path(forResource: nibName, ofType: "nib") else {
            return UIView()
        }
        
        let nib = UINib(nibName: nibName, bundle: bundle)
            
        // Assumes UIView is top level and only object in CustomView.xib file
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        return view
    }
}
