//
//  UIColorExtension.swift
//  nightguard
//
//  Created by Florian Preknya on 1/31/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

extension UIColor {
    
    static func nightguardRed() -> UIColor {
        return UIColor(red: 0.94, green: 0.11, blue: 0.13, alpha: 1.00)
    }
    
    static func nightguardOrange() -> UIColor {
        return UIColor(red: 0.93, green: 0.43, blue: 0.00, alpha: 1.00)
    }
    
    static func nightguardYellow() -> UIColor {
        return UIColor(red: 1.00, green: 0.74, blue: 0.01, alpha: 1.00)
    }
    
    static func nightguardGreen() -> UIColor {
        return UIColor(red: 0.57, green: 0.79, blue: 0.23, alpha: 1.00)
    }

    convenience init(red: UInt32, green: UInt32, blue: UInt32) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(netHex:UInt32) {
        self.init(red:(netHex >> 16) & 0xff, green:(netHex >> 8) & 0xff, blue:netHex & 0xff)
    }
}
