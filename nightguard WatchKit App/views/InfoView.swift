//
//  InfoView.swift
//  nightguard WatchKit Extension
//
//  Created by conversion to SwiftUI.
//  Copyright © 2015 private. All rights reserved.
//

import SwiftUI
import WatchKit

struct InfoView: View {

    @State private var baseUri: String = UserDefaultsRepository.baseUri.value
    @State private var versionText: String = ""
    @State private var cachedValuesText: String = ""
    @State private var backgroundUpdatesText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Version Label
                HStack {
                    Spacer()
                    Text(versionText)
                        .font(.system(size: 14))
                    Spacer()
                }

                // Nightscout URI Section
                Text("Nightscout URI:")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .center)

                TextField("http://...", text: $baseUri, onCommit: {
                    baseUriChanged()
                })

                // Cached Values Section
                Text("Caches Values:")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(cachedValuesText)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .center)

                // Background Updates Section
                Text("Background updates:")
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(backgroundUpdatesText)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .onAppear {
            displayLabels()
        }
    }

    private func baseUriChanged() {
        UserDefaultsRepository.baseUri.value = baseUri

        if UserDefaultsRepository.manuallySetUnits.value {
            // if the user decided to manually set the display units, we don't have to determine
            // them here. So just back off:
            return
        }

        NightscoutService.singleton.readStatus { (result: NightscoutRequestResult<Units>) in

            switch result {
            case .data(let units):
                UserDefaultsRepository.units.value = units
            case .error(_):
                print("Unable to determine units on the watch. Using the synced values from the ios app.")
            }
        }
    }

    private func displayLabels() {
        // version number
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionText = "V\(versionNumber).\(buildNumber)"

        // cached values
        let todaysBgData = NightscoutDataRepository.singleton.loadTodaysBgData()
        let yesterdaysBgData = NightscoutDataRepository.singleton.loadYesterdaysBgData()
        cachedValuesText = "\(todaysBgData.count) / \(yesterdaysBgData.count)"

        // background updates
        var text = "📱Updates initiated by phone app: \(BackgroundRefreshLogger.phoneUpdates)"
        text += "\nNew data: \(BackgroundRefreshLogger.phoneUpdatesWithNewData), existing: \(BackgroundRefreshLogger.phoneUpdatesWithSameData), old: \(BackgroundRefreshLogger.phoneUpdatesWithOldData)\n"

        text += "\n⌚Background updates: \(BackgroundRefreshLogger.backgroundRefreshes) (\(BackgroundRefreshLogger.formattedBackgroundRefreshesPerHour) per hour)"
        text += "\nBackground URL sessions: \(BackgroundRefreshLogger.backgroundURLSessions) (\(BackgroundRefreshLogger.formattedBackgroundRefreshesStartingURLSessions))"

        text += "\nNew data: \(BackgroundRefreshLogger.backgroundURLSessionUpdatesWithNewData), existing: \(BackgroundRefreshLogger.backgroundURLSessionUpdatesWithSameData), old: \(BackgroundRefreshLogger.backgroundURLSessionUpdatesWithOldData)\n"

        if !BackgroundRefreshLogger.receivedData.isEmpty {
            text += "\nReceived data:\n"
            text += BackgroundRefreshLogger.receivedData.joined(separator: "\n")
            text += "\n"
        }

        if !BackgroundRefreshLogger.logs.isEmpty {
            text += "\nLogs from background tasks:\n"
            text += BackgroundRefreshLogger.logs.joined(separator: "\n")
        }

        backgroundUpdatesText = text
    }
}
