//
//  MenuActionCell.swift
//  nightguard
//
//  Created by Florian Preknya on 4/22/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import XLActionController

class MenuActionCell: ActionCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initialize()
    }
    
    func initialize() {
        backgroundColor = .clear
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        selectedBackgroundView = backgroundView
        actionTitleLabel?.textColor = .white
        actionTitleLabel?.textAlignment = .left
    }
}
