//
//  VolumeChangeDetector.swift
//  nightguard
//
//  Created by Florian Preknya on 2/10/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation
import AVFoundation

/// System Output Volume listener class.
class VolumeChangeDetector: NSObject {
    
    var onVolumeChange: (() -> ())?
    
    var isActive: Bool = false {
        didSet {
            guard isActive != oldValue else {
                return
            }
            
            if isActive {
                do {
                    try AVAudioSession.sharedInstance().setActive(true, with: [])
                } catch {
                    print("Error activating audio session")
                }
                AVAudioSession.sharedInstance().addObserver(self, forKeyPath: "outputVolume", options: NSKeyValueObservingOptions.new, context: nil)
            } else {
                AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
            }
        }
    }
    
    deinit {
        isActive = false
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "outputVolume" {
            print("Volume changed!")
            onVolumeChange?()
        }
    }
}
