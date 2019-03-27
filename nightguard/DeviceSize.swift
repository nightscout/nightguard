//
//  DeviceSize.swift
//  nightguard
//
//  Created by Florian Preknya on 1/29/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation
import UIKit

enum DeviceSize {
    case iPhone4
    case iPhone5
    case iPhone6
    case iPhone6Plus
    case iPhoneX
    case iPhoneXR
    case iPhoneXMax
    case iPadMini
    case iPadPro
    case unknownDevice
    
    init() {
        
        func mapIdentifierToDevice() -> DeviceSize {
            
            if UIDevice.current.userInterfaceIdiom == .phone {
                switch UIScreen.main.nativeBounds.height {
                case 960:
                    return .iPhone4
                case 1136:
                    return .iPhone5
                case 1334:
                    return .iPhone6
                case 2208:
                    return .iPhone6Plus
                case 2436:
                    return .iPhoneX
                case 1792:
                    return .iPhoneXR
                case 2688:
                    return .iPhoneXMax
                default:
                    return .unknownDevice
                }
            } else if UIDevice.current.userInterfaceIdiom == .pad {
                
                switch UIScreen.main.nativeBounds.height {
                case 2048:
                    return .iPadMini
                case 2224, 2732:
                    return .iPadPro
                default:
                    return .unknownDevice
                }
            } else {
                return .unknownDevice
            }
        }
        
        self = mapIdentifierToDevice()
    }
    
    var description: String {
        
        switch self {
        case .iPhone4:                  return "iPhone 4"
        case .iPhone5:                  return "iPhone 5"
        case .iPhone6:                  return "iPhone 6"
        case .iPhone6Plus:              return "iPhone 6 Plus"
        case .iPhoneX:                  return "iPhoneX"
        case .iPhoneXR:                 return "iPhoneXR"
        case .iPhoneXMax:               return "iPhoneXMax"
        case .iPadMini:                 return "iPad Mini"
        case .iPadPro:                  return "iPod Pro"
        case .unknownDevice:            return "Unknown Device"
        }
    }
}

extension DeviceSize {
    var isSmall: Bool {
        return self == .iPhone4 || self == .iPhone5
    }
}
