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
 * Class that handles the playing and the volume of the alarm sound.
 */
class AlarmSound {
    
    static var isPlaying: Bool {
        return self.audioPlayer.isPlaying
    }
    
    static var isMuted: Bool {
        return self.audioPlayer.volume == 0
    }
    
    static var isTesting: Bool = false
    
    static let volumeChangeDetector = VolumeChangeDetector()
    
    static let fadeInTimeInterval = UserDefaultsValue<TimeInterval>(key: "fadeInTimeInterval", default: 0)  // fade-in time interval in seconds
    
    static let vibrate = UserDefaultsValue<Bool>(key: "vibrate", default: true)
    
    static let overrideSystemOutputVolume = UserDefaultsValue<Bool>(key: "overrideSystemOutputVolume", default: false)
    static let systemOutputVolume = UserDefaultsValue<Float>(key: "systemOutputVolume", default: 0.7)
    
    fileprivate static var systemOutputVolumeBeforeOverride: Float?
    
    fileprivate static var playingTimer: Timer?
    
    fileprivate static let soundURL = Bundle.main.url(forResource: "alarm", withExtension: "mp3")
    fileprivate static var audioPlayer : AVAudioPlayer = try! AVAudioPlayer(contentsOf: soundURL!)
    
    /*
     * Sets the audio volume to 0.
     */
    static func muteVolume() {
        self.audioPlayer.volume = 0
        self.restoreSystemOutputVolume()
    }
    
    /*
     * Sets the volume of the alarm back to the volume before it has been muted.
     */
    static func unmuteVolume() {
        if self.fadeInTimeInterval.value > 0 {
            self.audioPlayer.setVolume(1.0, fadeDuration: self.fadeInTimeInterval.value)
        } else {
            self.audioPlayer.volume = 1.0
        }
    }
    
    static func stop() {
        self.playingTimer?.invalidate()
        self.playingTimer = nil
        
        self.audioPlayer.stop()
        self.restoreSystemOutputVolume()
    }
    
    static func play() {
        
        guard !self.audioPlayer.isPlaying else {
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Play endless loops
            self.audioPlayer.numberOfLoops = -1
            
            // init volume before start playing (mute if fade-in)
            self.audioPlayer.volume = (self.fadeInTimeInterval.value > 0) ? 0.0 : 1.0
            
            self.audioPlayer.play()
            
            // do fade-in
            if self.fadeInTimeInterval.value > 0 {
                self.audioPlayer.setVolume(1.0, fadeDuration: self.fadeInTimeInterval.value)
            }
            
            self.playingTimer = Timer.schedule(repeatInterval: 1.0, handler: self.onPlayingTimer)
            
        } catch _ {
            print("Unable to play sound!")
        }
    }
    
    fileprivate static func onPlayingTimer(timer: Timer?) {
        
        // player should be playing, not muted!
        guard self.audioPlayer.isPlaying && !self.isMuted else {
            return
        }
        
        // application should be in active state!
        guard UIApplication.shared.applicationState == .active else {
            return
        }
        
        if self.overrideSystemOutputVolume.value {

            // keep the system output volume before overriding it
            if self.systemOutputVolumeBeforeOverride == nil {
                self.systemOutputVolumeBeforeOverride = MPVolumeView.volume
            }
            
            // override the system output volume
            if MPVolumeView.volume != self.systemOutputVolume.value {
                self.volumeChangeDetector.isActive = false
                MPVolumeView.volume = self.systemOutputVolume.value
            } else {
            
                // listen to user volume changes
                self.volumeChangeDetector.isActive = true
            }
        }
            
        if self.vibrate.value {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
    }
    
    fileprivate static func restoreSystemOutputVolume() {
        
        guard self.overrideSystemOutputVolume.value else {
            return
        }
        
        // cancel any volume change observations
        self.volumeChangeDetector.isActive = false
        
        // restore system output volume with its value before overriding it
        if let volumeBeforeOverride = self.systemOutputVolumeBeforeOverride {
            MPVolumeView.volume = volumeBeforeOverride
        }
        
        self.systemOutputVolumeBeforeOverride = nil
    }
}
