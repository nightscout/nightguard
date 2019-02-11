//
//  SnoozeActionsViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 2/10/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

class SnoozeActionsViewController: CustomFormViewController {
    
    private let quickActionCodes: [QuickSnoozeOption] =  [
        .doNothing,
        .showSnoozePopup,
        .snoozeOneMinute,
        .snoozeFiveMinutes,
        .snoozeTenMinutes
    ]

    override func constructForm() {
        
        form +++ Section(footer: "After an alert started, sometimes it is important to have a shortcut, a quick way to stop it for the moment.")
            +++ Section(header: "Quick Snoozing", footer: "NOTE: snoozing with volume buttons is enabled only if the \"Override System Volume\" option is ON (Alert Volume screen)")
            <<< makeQuickSnoozePickerRow(title: "Shaking the phone", userDefaultsValue: UserDefaultsRepository.shakingOnAlertSnoozeOption)
            <<< makeQuickSnoozePickerRow(title: "Volume Buttons", userDefaultsValue: UserDefaultsRepository.volumeKeysOnAlertSnoozeOption)
    }
    
    private func makeQuickSnoozePickerRow(title: String, userDefaultsValue: UserDefaultsValue<QuickSnoozeOption>) -> PickerInlineRow<Int> {
        
        return PickerInlineRow<Int>() { row in
            row.title = title
            row.cellStyle = .subtitle
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                guard let quickSnoozeOption = QuickSnoozeOption(rawValue: value) else { return nil}

                return "Will " + quickSnoozeOption.description
            }
            row.options = quickActionCodes.map { $0.rawValue }
            row.value = userDefaultsValue.value.rawValue
            }.onChange { row in
                guard let value = row.value else { return }
                guard let quickSnoozeOption = QuickSnoozeOption(rawValue: value) else { return }
                userDefaultsValue.value = quickSnoozeOption
        }
    }    
}
