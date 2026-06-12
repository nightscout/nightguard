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

    struct UpdateResult {
        let activityCount: Int
        let updatedActivityCount: Int
        let message: String

        var didUpdateAnyActivity: Bool {
            updatedActivityCount > 0
        }
    }
    
    private init() {}
    
    func startOrUpdateActivity(sgv: String, delta: String, trendArrow: String, date: Date, bgDelta: Double, sgvColor: UIColor, iob: String, cob: String) {
        #if canImport(ActivityKit)
        // Live Activities are only available on iOS 16.1+
        guard #available(iOS 16.1, *) else { return }
        
        // Check for Pro Subscription
        if !PurchaseManager.shared.hasProFeatureAccess {
            // End activity if it exists (e.g. subscription expired)
            endActivity()
            return
        }
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let contentState = makeContentState(
            sgv: sgv,
            delta: delta,
            trendArrow: trendArrow,
            date: date,
            bgDelta: bgDelta,
            sgvColor: sgvColor,
            iob: iob,
            cob: cob
        )
        
        // Check if we already have an activity running
        let activities = Activity<NightguardActivityAttributes>.activities
        if !activities.isEmpty {
            // Update all active activities
            for activity in activities {
                Task {
                    if #available(iOS 16.2, *) {
                        let content = ActivityContent(state: contentState, staleDate: nil)
                        await activity.update(content)
                    } else {
                        await activity.update(using: contentState)
                    }
                }
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

    @available(iOS 16.1, *)
    func updateExistingActivities(with nightscoutData: NightscoutData) async -> UpdateResult {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return UpdateResult(
                activityCount: 0,
                updatedActivityCount: 0,
                message: "Live Activities are disabled in system settings"
            )
        }

        guard PurchaseManager.shared.hasProFeatureAccess else {
            return UpdateResult(
                activityCount: Activity<NightguardActivityAttributes>.activities.count,
                updatedActivityCount: 0,
                message: "Pro access unavailable; skipped background Live Activity update"
            )
        }

        let activities = Activity<NightguardActivityAttributes>.activities
        guard !activities.isEmpty else {
            return UpdateResult(
                activityCount: 0,
                updatedActivityCount: 0,
                message: "No existing Live Activities found"
            )
        }

        let contentState = makeContentState(from: nightscoutData)
        var updatedActivityCount = 0
        for activity in activities {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: contentState)
            }
            updatedActivityCount += 1
        }

        return UpdateResult(
            activityCount: activities.count,
            updatedActivityCount: updatedActivityCount,
            message: "Updated \(updatedActivityCount) of \(activities.count) Live Activities"
        )
        #else
        return UpdateResult(
            activityCount: 0,
            updatedActivityCount: 0,
            message: "ActivityKit unavailable"
        )
        #endif
    }

    func update(with nightscoutData: NightscoutData) {
        #if os(iOS)
        let displayValues = makeDisplayValues(from: nightscoutData)

        startOrUpdateActivity(
            sgv: displayValues.sgv,
            delta: displayValues.delta,
            trendArrow: displayValues.trendArrow,
            date: displayValues.date,
            bgDelta: displayValues.bgDelta,
            sgvColor: displayValues.sgvColor,
            iob: displayValues.iob,
            cob: displayValues.cob
        )
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

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private func makeContentState(from nightscoutData: NightscoutData) -> NightguardActivityAttributes.ContentState {
        let displayValues = makeDisplayValues(from: nightscoutData)
        return makeContentState(
            sgv: displayValues.sgv,
            delta: displayValues.delta,
            trendArrow: displayValues.trendArrow,
            date: displayValues.date,
            bgDelta: displayValues.bgDelta,
            sgvColor: displayValues.sgvColor,
            iob: displayValues.iob,
            cob: displayValues.cob
        )
    }

    @available(iOS 16.1, *)
    private func makeContentState(
        sgv: String,
        delta: String,
        trendArrow: String,
        date: Date,
        bgDelta: Double,
        sgvColor: UIColor,
        iob: String,
        cob: String
    ) -> NightguardActivityAttributes.ContentState {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        sgvColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return NightguardActivityAttributes.ContentState(
            sgv: sgv,
            delta: delta,
            trendArrow: trendArrow,
            date: date,
            bgDelta: bgDelta,
            sgvColorRed: Double(red),
            sgvColorGreen: Double(green),
            sgvColorBlue: Double(blue),
            iob: iob,
            cob: cob
        )
    }
    #endif

    private func makeDisplayValues(from nightscoutData: NightscoutData) -> (
        sgv: String,
        delta: String,
        trendArrow: String,
        date: Date,
        bgDelta: Double,
        sgvColor: UIColor,
        iob: String,
        cob: String
    ) {
        let sgv = UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)
        return (
            sgv: sgv,
            delta: UnitsConverter.mgdlToDisplayUnitsWithSign("\(nightscoutData.bgdelta)"),
            trendArrow: nightscoutData.bgdeltaArrow,
            date: Date(timeIntervalSince1970: Double(nightscoutData.time.int64Value / 1000)),
            bgDelta: Double(nightscoutData.bgdelta),
            sgvColor: UIColorChanger.getBgColor(sgv),
            iob: nightscoutData.iob,
            cob: nightscoutData.cob
        )
    }
}
