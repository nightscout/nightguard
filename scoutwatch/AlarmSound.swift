//
//  AlarmSound.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 03.01.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/*
 * Class that handles the playing of the alarm sound. 
 */
class AlarmPlayer {
    private static let soundURL = NSBundle.mainBundle().URLForResource("alarm", withExtension: "mp3")
    private static var audioPlayer : AVAudioPlayer? = nil
    
    /*
     * Changes the alarm sound volume. 1.0 is 100% volume. 0.0 is 0% volume.
     */
    static func changeAlarmVolume(volume : Float) {
        self.audioPlayer?.volume = volume
        
        // change the system volume, so that sound will be played whatever system
        // settings you have
        let volumeView = MPVolumeView()
            
        for view in volumeView.subviews {
            if (NSStringFromClass(view.classForCoder) == "MPVolumeSlider") {
                let slider = view as! UISlider
                slider.setValue(volume, animated: false)
            }
        }
    }
    
    static func getAlarmVolume() -> Float {
        let volumeView = MPVolumeView()
        
        for view in volumeView.subviews {
            if (NSStringFromClass(view.classForCoder) == "MPVolumeSlider") {
                let slider = view as! UISlider
                return slider.value
            }
        }
        return 0
    }
    
    static func stopAlarm() {
        
        if (audioPlayer == nil) {
            return
        }
        
        self.audioPlayer!.stop()
    }
    
    static func playAlarm() {
        do {
            if self.audioPlayer == nil {
                try self.audioPlayer = AVAudioPlayer(contentsOfURL: soundURL!)
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                try AVAudioSession.sharedInstance().setActive(true)
                //UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
                
                // Play endless loops
                self.audioPlayer?.numberOfLoops = -1
            }
            self.audioPlayer!.play()
        } catch _ {
            print("Unable to play sound!")
        }
    }
}