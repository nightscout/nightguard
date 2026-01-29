//
//  LiveActivityAttributes.swift
//  nightguard
//
//  Created by Gemini CLI.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct NightguardActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var sgv: String
        var delta: String
        var trendArrow: String
        var date: Date
        var bgDelta: Double
        var sgvColorRed: Double
        var sgvColorGreen: Double
        var sgvColorBlue: Double
        var iob: String
        var cob: String
    }

    // Fixed non-changing properties about your activity go here!
}
#endif
