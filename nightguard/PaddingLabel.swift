//
//  PaddingLabel.swift
//  nightguard
//
//  Created by Florian Preknya on 6/14/18.
//  Copyright © 2018 private. All rights reserved.
//

import UIKit

class PaddingLabel: UILabel {
    
    var insets : UIEdgeInsets = UIEdgeInsets() {
        didSet {
            super.invalidateIntrinsicContentSize()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width += insets.left + insets.right
        size.height += insets.top + insets.bottom
        return size
    }
    
    override func drawText(in rect: CGRect) {
        return super.drawText(in: rect.inset(by: insets))
    }
}
