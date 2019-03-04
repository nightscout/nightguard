//
//  MissedReadingsViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 2/25/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

class MissedReadingsViewController: CustomFormViewController {
    
    fileprivate let alarmOptions = [15, 20, 25, 30, 35, 40, 45]
    private var selectableSection: SelectableSection<ListCheckRow<Int>>!
    
    override func constructForm() {
        
        selectableSection = SelectableSection<ListCheckRow<Int>>("Alert when no data for more than", selectionType: .singleSelection(enableDeselection: true))
        selectableSection.onSelectSelectableRow = { cell, row in
            guard let value = row.value else { return }
            AlarmRule.minutesWithoutValues.value = value
        }
        selectableSection.hidden = .function(["Missed Readings"], { form -> Bool in
            let row: RowOf<Bool>! = form.rowBy(tag: "Missed Readings")
            return row.value ?? false == false
        })
        
        for option in alarmOptions {
            selectableSection <<< ListCheckRow<Int>("\(option) Minutes") { lrow in
                lrow.title = "\(option) Minutes"
                lrow.selectableValue = option
                lrow.value = (option == AlarmRule.minutesWithoutValues.value) ? option : nil
            }
        }
        
        form +++ Section(header: "", footer: "Alerts when no data is received for a longer period. We suggest leaving this check ALWAYS ON.")
            <<< SwitchRow("Missed Readings") { row in
                row.title = "Missed Readings"
                row.value = AlarmRule.noDataAlarmEnabled.value
                }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    
                    if value {
                        AlarmRule.noDataAlarmEnabled.value = value
                    } else {
                        self?.showYesNoAlert(
                            title: "ARE YOU SURE?",
                            message: "For your safety, keep this switch ON for receiving alarms when no readings!",
                            yesHandler: {
                                AlarmRule.noDataAlarmEnabled.value = value
                        },
                            noHandler: {
                                row.value = true
                                row.updateCell()
                        })
                    }
            }
            
            +++ selectableSection
    }
}
