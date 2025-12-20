//
//  Comparable+Extensions.swift
//  nightguard
//
//  Created by Florian Preknya on 3/22/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
