//
//  DisplayOptionsSectionView.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import SwiftUI

struct DisplayOptionsSectionView: View {
    @Binding var showStats: Bool
    @Binding var showCareAndLoopData: Bool
    @Binding var showYesterdaysBgs: Bool
    @Binding var checkBGEveryMinute: Bool
    @Binding var showBGOnAppBadge: Bool
    @Binding var appleHealthSync: Bool
    @Binding var showAppleHealthAlert: Bool
    
    var body: some View {
        Section {
            Toggle("Show Statistics", isOn: $showStats)
                .onChange(of: showStats) { newValue in
                    UserDefaultsRepository.showStats.value = newValue
                }

            Toggle("Show Care/Loop Data", isOn: $showCareAndLoopData)
                .onChange(of: showCareAndLoopData) { newValue in
                    UserDefaultsRepository.showCareAndLoopData.value = newValue
                }

            Toggle("Show Yesterdays BGs", isOn: $showYesterdaysBgs)
                .onChange(of: showYesterdaysBgs) { newValue in
                    UserDefaultsRepository.showYesterdaysBgs.value = newValue
                }

            Toggle("Check BG every minute", isOn: $checkBGEveryMinute)
                .onChange(of: checkBGEveryMinute) { newValue in
                    UserDefaultsRepository.checkBGEveryMinute.value = newValue
                }

            Toggle("Show BG on App Badge", isOn: $showBGOnAppBadge)
                .onChange(of: showBGOnAppBadge) { newValue in
                    SharedUserDefaultsRepository.showBGOnAppBadge.value = newValue
                }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Synchronize with Apple Health", isOn: $appleHealthSync)
                    .onChange(of: appleHealthSync) { newValue in
                        if AppleHealthService.singleton.isAuthorized() {
                            showAppleHealthAlert = true
                            appleHealthSync = true
                        } else {
                            AppleHealthService.singleton.requestAuthorization()
                        }
                    }
                
                Text(NSLocalizedString("AppleHealthSyncDescription", comment: "Description for Apple Health synchronization"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}
