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
    
    private let quickActionCodes =  [-1, 0, 1, 5, 10]

    override func constructForm() {
        
        let shakingSection = makeSection(header: "Shaking the phone will", footer: "", userDefaultsValue: UserDefaultsRepository.shakingOnAlertActionCode)
        let volumeKeysSection = makeSection(header: "Pressing the Volume Keys will", footer: "This action is available only if \"Override System Volume\" option is ON (in Alert Volume screen)", userDefaultsValue: UserDefaultsRepository.volumeKeysOnAlertActionCode)
        
        form +++ Section(footer: "After an alert started, sometimes it is important to have a shortcut, a quick way to stop it for the moment.")
            +++ shakingSection
            +++ volumeKeysSection
    }
    
    private func makeSection(header: String, footer: String, userDefaultsValue: UserDefaultsValue<Int>) -> SelectableSection<ListCheckRow<Int>> {
        
        let section = SelectableSection<ListCheckRow<Int>>(header: header, footer: footer, selectionType: .singleSelection(enableDeselection: true))
        section.onSelectSelectableRow = { cell, row in
            guard let value = row.value else { return }
            userDefaultsValue.value = value
        }
        
        for option in quickActionCodes {
            section <<< ListCheckRow<Int>() { row in
                
                switch option {
                case -1: row.title = "Do Nothing"
                case 0: row.title = "Open the Snoozer Dialog"
                case 1: row.title = "Snooze for 1 Minute"
                default:
                    row.title =  "Snooze for \(option) Minutes"
                }
                
                row.selectableValue = option
                row.value = (option == userDefaultsValue.value) ? option : nil
            }
        }
        
        return section
    }
}
