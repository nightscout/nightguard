//
//  LiveActivityManager.swift
//  nightguard
//
//  Created by Gemini CLI.
//

import Foundation
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private init() {}
    
    func startOrUpdateActivity(sgv: String, delta: String, trendArrow: String, date: Date, bgDelta: Double, sgvColor: UIColor) {
        #if canImport(ActivityKit)
        // Live Activities are only available on iOS 16.1+
        guard #available(iOS 16.1, *) else { return }
        
        // Check for Pro Subscription
        if !PurchaseManager.shared.isProAccessAvailable {
            // End activity if it exists (e.g. subscription expired)
            endActivity()
            return
        }
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        sgvColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let contentState = NightguardActivityAttributes.ContentState(
            sgv: sgv,
            delta: delta,
            trendArrow: trendArrow,
            date: date,
            bgDelta: bgDelta,
            sgvColorRed: Double(red),
            sgvColorGreen: Double(green),
            sgvColorBlue: Double(blue)
        )
        
        // Check if we already have an activity running
        if let currentActivity = Activity<NightguardActivityAttributes>.activities.first {
            // Update
            Task {
                await currentActivity.update(using: contentState)
            }
        } else {
            // Start
            let attributes = NightguardActivityAttributes()
            do {
                let _ = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
            } catch {
                print("Error starting live activity: \(error.localizedDescription)")
            }
        }
        #endif
    }
    
    func endActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        
        Task {
            for activity in Activity<NightguardActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
