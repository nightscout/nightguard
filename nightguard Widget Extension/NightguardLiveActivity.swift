//
//  NightguardLiveActivity.swift
//  nightguard Widget Extension
//
//  Created by Gemini CLI.
//

import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct NightguardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightguardActivityAttributes.self) { context in
            // Lock screen/banner UI
            VStack(alignment: .leading) {
                HStack {
                    Text(context.state.sgv)
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text(context.state.trendArrow)
                                .font(.title)
                            Text(context.state.delta)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        Text(context.state.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
            }
            .activityBackgroundTint(nil)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .center) {
                        Text(context.state.sgv)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
                    }
                    .padding(.leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        HStack(spacing: 2) {
                            Text(context.state.delta)
                                .font(.headline)
                                .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
                            Text(context.state.trendArrow)
                                .font(.title2)
                        }
                    }
                    .padding(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        Text(context.state.date, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            } compactLeading: {
                Text(context.state.sgv)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text(context.state.trendArrow)
                    Text(context.state.delta)
                }
                .font(.caption)
            } minimal: {
                Text(context.state.sgv)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
            }
            .widgetURL(URL(string: "nightguard://open"))
            .keylineTint(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
        }
    }
}
#endif
