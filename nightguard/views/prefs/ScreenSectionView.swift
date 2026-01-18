//
//  ScreenSectionView.swift
//  nightguard
//
//  Created by Gemini on 2026-01-15.
//

import SwiftUI

struct ScreenSectionView: View {
    @Binding var keepScreenActive: Bool
    @Binding var dimScreenWhenIdle: Int
    @Binding var showKeepScreenActiveAlert: Bool
    
    private let dimScreenOptions = [0, 1, 2, 3, 4, 5, 10, 15]
    
    var body: some View {
        Section(
            footer: Text("Keeping the screen active is of paramount importance if using the app as a night guard. We suggest leaving it ALWAYS ON.")
                .font(.footnote)
        ) {
            Toggle("Keep the Screen Active", isOn: $keepScreenActive)
                .onChange(of: keepScreenActive) { newValue in
                    if newValue {
                        SharedUserDefaultsRepository.screenlockSwitchState.value = newValue
                    } else {
                        showKeepScreenActiveAlert = true
                    }
                }

            if keepScreenActive {
                Picker("Dim Screen When Idle", selection: $dimScreenWhenIdle)
                {
                    ForEach(dimScreenOptions, id: \.self) { option in
                        Text(dimScreenLabel(for: option)).tag(option)
                    }
                }
                .pickerStyle(.automatic)
                .onChange(of: dimScreenWhenIdle) { newValue in
                    UserDefaultsRepository.dimScreenWhenIdle.value = newValue
                }
            }
        }
    }
    
    private func dimScreenLabel(for minutes: Int) -> String {
        switch minutes {
        case 0:
            return NSLocalizedString("Never", comment: "Option")
        case 1:
            return NSLocalizedString("1 Minute", comment: "Option")
        default:
            return "\(minutes) " + NSLocalizedString("Minutes", comment: "Option")
        }
    }
}
