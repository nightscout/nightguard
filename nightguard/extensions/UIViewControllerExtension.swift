//
//  UIViewControllerExtension.swift
//  nightguard
//
//  Created by Dirk Hermanns on 17.03.17.
//  Copyright © 2017 private. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    
    // The maximum Chart-Width is restricted to 4096 / Device-Scale pixels
    // So take care, that this is not exceeded. Otherwise we get nothing but a
    // black texture.
    func maximumDeviceTextureWidth() -> CGFloat {
        return 4096 / UIScreen.main.scale
    }
}
