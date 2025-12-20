//
//  UIScreen+AnimatedBrightness.swift
//  nightguard
//
//  Created by Florian Preknya on 2/16/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit

extension UIScreen {
    
    func setBrightness(_ value: CGFloat, animated: Bool) {
        if animated {
            _brightnessQueue.cancelAllOperations()
            let step: CGFloat = 0.04 * ((value > brightness) ? 1 : -1)
            _brightnessQueue.addOperations(stride(from: brightness, through: value, by: step).map({ [weak self] value -> Operation in
                let blockOperation = BlockOperation()
                unowned let _unownedOperation = blockOperation
                blockOperation.addExecutionBlock({
                    if !_unownedOperation.isCancelled {
                        Thread.sleep(forTimeInterval: 1 / 60.0)
                        self?.brightness = value
                    }
                })
                return blockOperation
            }), waitUntilFinished: false)
        } else {
            brightness = value
        }
    }
    
}

private let _brightnessQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
}()
