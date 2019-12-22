//
//  UserInteractionDetectorWindow.swift
//  nightguard
//
//  Created by Florian Preknya on 2/12/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation
import UIKit

extension NSNotification.Name {
    public static let UserInteractionTimeout: NSNotification.Name = NSNotification.Name(rawValue: "UserInteractionTimeout")
}

/**
 A special UIWindow that detects user interactions and notifies when timeout
 */

class UserInteractionDetectorWindow: UIWindow {
    
    static let ApplicationDidTimoutNotification = "AppTimout"
    
    /// User interaction timeout (seconds).
    ///
    /// After passing the timeout with no user interaction (or system interruption), the UserInteractionTimeout
    /// notification is sent and the screen is dimmed; otherwise, the timer is reseted and user interaction detection restarts.
    var timeout: TimeInterval? {
        didSet {
            resetIdleTimer()
        }
    }
    
    /// When user interaction timeout has passed, should the phone screen brightness decrease?
    var dimScreenOnTimeout: Bool = true
    
    /// A specific view to show while the screen is dimmed
    var dimScreenViewType: UIView.Type?
    
    private var idleTimer: Timer?
    private var dimView: UIView?
    private var originalBrightness: CGFloat?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Listen for any touch. If the screen receives a touch, the timer is reset.
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
        
        // only when app is active!
        guard UIApplication.shared.applicationState == .active else {
            return
        }

        // continue only if user activity timeout is set
        guard let timeout = self.timeout, timeout > 0 else {
            return
        }
        
        if idleTimer != nil {
            self.resetIdleTimer()
        }
        
        if let touches = event.allTouches {
            for touch in touches {
                if touch.phase == UITouch.Phase.began {
                    self.resetIdleTimer()
                }
            }
        }
    }
    
    // Reset the timer because of user interaction or system interruption; also reset brightness & remove dim view overlay (if on).
    private func resetIdleTimer() {
        stopIdleTimer()

        if let timeout = self.timeout, timeout > 0 {
            
            // recreate & schedule the timer
            idleTimer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(self.idleTimerExceeded), userInfo: nil, repeats: false)
        }
        
        if let brightness = self.originalBrightness {
            
            // reset the brightness to previous value...
            DispatchQueue.main.async {
                UIScreen.main.brightness = brightness
                self.originalBrightness = nil
            }
            
            // ... and remove the dim view overlay
            dimView?.removeFromSuperview()
            dimView = nil
        }
    }
    
    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
    
    @objc func applicationDidEnterBackground(_ notification: Notification) {
        stopIdleTimer()
    }
    
    @objc func applicationWillEnterForeground(_ notification: Notification) {
        resetIdleTimer()
    }
    
    // If the timer reaches the limit as defined in timeout, post the timeout notification & dim the screen (if configured so).
    @objc func idleTimerExceeded() {
        
        idleTimer?.invalidate()
        idleTimer = nil
        
        // continue only if app is active!
        guard UIApplication.shared.applicationState == .active else {
            return
        }

        // send notification
        NotificationCenter.default.post(name:Notification.Name.UserInteractionTimeout, object: nil)
        
        if dimScreenOnTimeout {
            
            // create the overlay "dim view" - a transparent view will be a default, it will catch the first user interaction, then it will be removed from screen
            let viewType = dimScreenViewType ?? UIView.self
            dimView = viewType.init(frame: CGRect(origin: self.bounds.origin, size: self.bounds.size))
            addSubview(dimView!)
    
            // reduce screen brightness
            DispatchQueue.main.async {
                self.originalBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 0
            }
        }
    }
}
