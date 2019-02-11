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
        
        let shakingSection = makeSection(header: "Shaking the phone will", footer: "", userDefaultsValue: UserDefaultsRepository.shakingOnAlertSnoozeOption)
        let volumeKeysSection = makeSection(header: "Pressing the Volume Keys will", footer: "This action is available only if \"Override System Volume\" option is ON (in Alert Volume screen)", userDefaultsValue: UserDefaultsRepository.volumeKeysOnAlertSnoozeOption)
        
        form +++ Section(footer: "After an alert started, sometimes it is important to have a shortcut, a quick way to stop it for the moment.")
            +++ shakingSection
            +++ volumeKeysSection
    }
    
    private func makeSection(header: String, footer: String, userDefaultsValue: UserDefaultsValue<QuickSnoozeOption>) -> SelectableSection<ListCheckRow<Int>> {
        
        let section = SelectableSection<ListCheckRow<Int>>(header: header, footer: footer, selectionType: .singleSelection(enableDeselection: true))
        section.onSelectSelectableRow = { cell, row in
            guard let value = row.value else { return }
            guard let action = QuickSnoozeOption(rawValue: value) else { return }
            userDefaultsValue.value = action
        }
        
        for option in quickActionCodes {
            section <<< ListCheckRow<Int>() { row in
                
                row.title = option.description
                row.selectableValue = option.rawValue
                row.value = (option == userDefaultsValue.value) ? option.rawValue : nil
            }
        }
        
        return section
    }
}
