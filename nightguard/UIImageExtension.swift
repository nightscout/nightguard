//
//  UIImageExtension.swift
//  nightguard
//
//  Created by Dirk Hermanns on 07.11.21.
//  Copyright © 2021 private. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {

    static func emptyImage(with size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
