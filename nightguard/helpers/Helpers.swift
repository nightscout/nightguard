//
//  Helpers.swift
//  nightguard
//
//  Created by Florian Preknya on 11/14/18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

func dispatchOnMain(_ closure: @escaping () -> ()) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}

func delay(_ delay:Double, closure: @escaping () -> ()) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure
    )
}
