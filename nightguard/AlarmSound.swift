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
    private static let soundURL = NSBundle.mainBundle().URLForResource("alarm", withExtension: "mp3")
    private static var audioPlayer : AVAudioPlayer = try! AVAudioPlayer(contentsOfURL: soundURL!)
    
    private static var mute : Bool = false
    private static var volumeBeforeMute : Float = 0
    
    /*
     * Sets the audio volume to 0.
     */
    static func muteVolume() {
        mute = true;
        volumeBeforeMute = self.audioPlayer.volume
        self.audioPlayer.volume = 0
    }
    
    /*
     * Sets the volume of the alarm back to the volume before it has been muted.
     */
    static func unmuteVolume() {
        mute = false;
        self.audioPlayer.volume = volumeBeforeMute
    }	
    
    static func stop() {
        
        self.audioPlayer.stop()
    }
    
    static func play() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
                
            // Play endless loops
            self.audioPlayer.numberOfLoops = -1
            self.audioPlayer.play()
        } catch _ {
            print("Unable to play sound!")
        }
    }
}