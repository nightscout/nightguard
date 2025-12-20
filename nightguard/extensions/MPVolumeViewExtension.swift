//
//  MPVolumeViewExtension.swift
//  nightguard
//
//  Created by Florian Preknya on 2/10/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

/// MPVolumeView extension used for controlling the system output volume 
extension MPVolumeView {
    
    static var volume: Float {
        get {
            return AVAudioSession.sharedInstance().outputVolume
            //            let volumeView = MPVolumeView()
            //            let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
            //            return slider?.value ?? 0.5
        }
        set {
            let volumeView = MPVolumeView()
            let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
                slider?.value = newValue
            }
        }
    }
}
