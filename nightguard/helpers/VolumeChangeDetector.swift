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
                AudioSessionController.activatePlayback(context: "VolumeChangeDetector") { _ in }
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
            #if MAIN_APP
            AppLogger.singleton.debug("Volume changed!")
            #endif
            onVolumeChange?()
        }
    }
}

enum AudioSessionController {
    static func activatePlayback(context: String, completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playback)
        } catch {
            NSLog("\(context) - error configuring audio session: \(error)")
            completion(false)
            return
        }

        #if os(watchOS)
        if #available(watchOS 5.0, *) {
            session.activate(options: []) { activated, error in
                if let error = error {
                    NSLog("\(context) - error activating audio session: \(error)")
                }
                completion(activated)
            }
        } else {
            activateSynchronously(session, context: context, completion: completion)
        }
        #else
        if #available(iOS 27.0, *) {
            session.activate(options: []) { activated, error in
                if let error = error {
                    NSLog("\(context) - error activating audio session: \(error)")
                }
                completion(activated)
            }
        } else {
            activateSynchronously(session, context: context, completion: completion)
        }
        #endif
    }

    static func deactivatePlayback() {
        let session = AVAudioSession.sharedInstance()

        #if os(watchOS)
        if #available(watchOS 27.0, *) {
            session.deactivate(options: .notifyOthersOnDeactivation) { _, error in
                if let error = error {
                    NSLog("AlarmSound - error deactivating audio session: \(error)")
                }
            }
        } else {
            deactivateSynchronously(session)
        }
        #else
        if #available(iOS 27.0, *) {
            session.deactivate(options: .notifyOthersOnDeactivation) { _, error in
                if let error = error {
                    NSLog("AlarmSound - error deactivating audio session: \(error)")
                }
            }
        } else {
            deactivateSynchronously(session)
        }
        #endif
    }

    private static func activateSynchronously(
        _ session: AVAudioSession,
        context: String,
        completion: @escaping (Bool) -> Void
    ) {
        do {
            try session.setActive(true)
            completion(true)
        } catch {
            NSLog("\(context) - error activating audio session: \(error)")
            completion(false)
        }
    }

    private static func deactivateSynchronously(_ session: AVAudioSession) {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
