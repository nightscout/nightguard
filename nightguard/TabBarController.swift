//
//  UITabBarController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 23.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import UIKit

class TabBarController: UITabBarController {
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        
        if let selectedViewController = self.selectedViewController {
            return selectedViewController.supportedInterfaceOrientations
        }
        return .allButUpsideDown
    }
}
