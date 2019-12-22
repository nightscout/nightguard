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
        return self.audioPlayer?.isPlaying == true
    }
    
    static var isMuted: Bool {
        return self.muted
    }
    
    static var isTesting: Bool = false
    
    static let volumeChangeDetector = VolumeChangeDetector()
    
    static let fadeInTimeInterval = UserDefaultsValue<TimeInterval>(key: "fadeInTimeInterval", default: 0)  // fade-in time interval in seconds
    
    static let vibrate = UserDefaultsValue<Bool>(key: "vibrate", default: true)
    
    static let overrideSystemOutputVolume = UserDefaultsValue<Bool>(key: "overrideSystemOutputVolume", default: false)
    static let systemOutputVolume = UserDefaultsValue<Float>(key: "systemOutputVolume", default: 0.7)
    
    fileprivate static var systemOutputVolumeBeforeOverride: Float?
    
    fileprivate static var playingTimer: Timer?
    
    fileprivate static let soundURL = Bundle.main.url(forResource: "alarm", withExtension: "mp3")!
    fileprivate static var audioPlayer: AVAudioPlayer?
    fileprivate static let audioPlayerDelegate = AudioPlayerDelegate()
    
    fileprivate static var muted = false
    
    /*
     * Sets the audio volume to 0.
     */
    static func muteVolume() {
        self.audioPlayer?.volume = 0
        self.muted = true
        self.restoreSystemOutputVolume()
    }
    
    /*
     * Sets the volume of the alarm back to the volume before it has been muted.
     */
    static func unmuteVolume() {
        if self.fadeInTimeInterval.value > 0 {
            self.audioPlayer?.setVolume(1.0, fadeDuration: self.fadeInTimeInterval.value)
        } else {
            self.audioPlayer?.volume = 1.0
        }
        self.muted = false
    }
    
    static func stop() {
        self.playingTimer?.invalidate()
        self.playingTimer = nil
        
        self.audioPlayer?.stop()
        self.audioPlayer = nil
        
        self.restoreSystemOutputVolume()
    }
    
    static func play() {
        
        guard !self.isPlaying else {
            return
        }
        
        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: self.soundURL)
            self.audioPlayer!.delegate = self.audioPlayerDelegate
            
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Play endless loops
            self.audioPlayer!.numberOfLoops = -1
            
            // init volume before start playing (mute if fade-in)
            
            self.audioPlayer!.volume = (self.muted || (self.fadeInTimeInterval.value > 0)) ? 0.0 : 1.0
            
            if !self.audioPlayer!.prepareToPlay() {
                NSLog("AlarmSound - audio player failed preparing to play")
            }
            
            if self.audioPlayer!.play() {
                if !self.isPlaying {
                    NSLog("AlarmSound - not playing after calling play")
                    NSLog("AlarmSound - rate value: \(self.audioPlayer!.rate)")
                }
            } else {
                NSLog("AlarmSound - audio player failed to play")
            }
            
            
            // do fade-in
            if !self.muted && (self.fadeInTimeInterval.value > 0) {
                self.audioPlayer!.setVolume(1.0, fadeDuration: self.fadeInTimeInterval.value)
            }
            
            self.playingTimer = Timer.schedule(repeatInterval: 1.0, handler: self.onPlayingTimer)
            
        } catch let error {
            NSLog("AlarmSound - unable to play sound; error: \(error)")
        }
    }
    
    fileprivate static func onPlayingTimer(timer: Timer?) {
        
        // player should be playing, not muted!
        guard self.isPlaying && !self.isMuted else {
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

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {

    /* audioPlayerDidFinishPlaying:successfully: is called when a sound has finished playing. This method is NOT called if the player is stopped due to an interruption. */
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        NSLog("AlarmRule - audioPlayerDidFinishPlaying (\(flag))")
    }
    
    /* if an error occurs while decoding it will be reported to the delegate. */
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            NSLog("AlarmRule - audioPlayerDecodeErrorDidOccur: \(error)")
        } else {
            NSLog("AlarmRule - audioPlayerDecodeErrorDidOccur")
        }
    }
    
    /* AVAudioPlayer INTERRUPTION NOTIFICATIONS ARE DEPRECATED - Use AVAudioSession instead. */
    
    /* audioPlayerBeginInterruption: is called when the audio session has been interrupted while the player was playing. The player will have been paused. */
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        NSLog("AlarmRule - audioPlayerBeginInterruption")
    }
    
    
    /* audioPlayerEndInterruption:withOptions: is called when the audio session interruption has ended and this player had been interrupted while playing. */
    /* Currently the only flag is AVAudioSessionInterruptionFlags_ShouldResume. */
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        NSLog("AlarmRule - audioPlayerEndInterruption withOptions: \(flags)")
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
