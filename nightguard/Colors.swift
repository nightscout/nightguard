//
//  Colors.swift
//  nightguard
//
//  Created by Florian Preknya on 2/1/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

/// Definition of all the colors used in the app
extension UIColor {
    
    struct App {
        
        // Phone app colors
        #if os(iOS)
        
        // Preferences/Alarms screen colors
        struct Preferences {
            static let text = UIColor.white
            static let detailText = UIColor.lightGray
            static let placeholderText = UIColor.lightGray
            static let headerText = UIColor.gray
            static let footerText = UIColor.gray
            static let background = UIColor(netHex: 0x171717)
            static let rowBackground = UIColor(netHex: 0x1C1C1E)
            static let separator = UIColor(netHex: 0x3F3F3F)
        }
        
        #endif
    }
}
