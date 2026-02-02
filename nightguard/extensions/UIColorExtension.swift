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

    static func nightguardAccent() -> UIColor {
        return nightguardGreen()
    }

    static func nightguardContrastfulD1() -> UIColor {
        return hexStringToUIColor(hex: "#F5793A")
    }
    
    static func nightguardContrastfulD2() -> UIColor {
        return hexStringToUIColor(hex: "#A95AA1")
    }
    
    static func nightguardContrastfulD3() -> UIColor {
        return hexStringToUIColor(hex: "#85C0F9")
    }
    
    static func nightguardContrastfulD4() -> UIColor {
        return hexStringToUIColor(hex: "#C6D4E1")
    }
    
    static func nightguardContrastfulD5() -> UIColor {
        return hexStringToUIColor(hex: "#0F2080")
    }
    
    static func hexStringToUIColor(hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return UIColor.gray
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
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
