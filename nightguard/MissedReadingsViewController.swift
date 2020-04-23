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
        
        selectableSection = SelectableSection<ListCheckRow<Int>>(NSLocalizedString("Alert when no data for more than", comment: "Label for Alert when no data"), selectionType: .singleSelection(enableDeselection: true))
        selectableSection.onSelectSelectableRow = { cell, row in
            guard let value = row.value else { return }
            AlarmRule.minutesWithoutValues.value = value
        }
        selectableSection.hidden = .function([NSLocalizedString("Missed Readings", comment: "Alarm settings title: Missed readings")], { form -> Bool in
            let row: RowOf<Bool>! = form.rowBy(tag: "Missed Readings")
            return row.value ?? false == false
        })
        
        for option in alarmOptions {
            selectableSection <<< ListCheckRow<Int>("\(option) Minutes") { lrow in
                lrow.title = "\(option) " + NSLocalizedString("Minutes", comment: "Option")
                lrow.selectableValue = option
                lrow.value = (option == AlarmRule.minutesWithoutValues.value) ? option : nil
            }
        }
        
        form +++ Section(header: "", footer: NSLocalizedString("Alerts when no data is received for a longer period. We suggest leaving this check ALWAYS ON.", comment: "Footer for Alerts when no data is received"))
            <<< SwitchRow("Missed Readings") { row in
                row.title = NSLocalizedString("Missed Readings", comment: "Alarm settings title: Missed readings")
                row.value = AlarmRule.noDataAlarmEnabled.value
                }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    
                    if value {
                        AlarmRule.noDataAlarmEnabled.value = value
                    } else {
                        self?.showYesNoAlert(
                            title: NSLocalizedString("ARE YOU SURE?", comment: "Title for confirmation"),
                            message: NSLocalizedString("For your safety, keep this switch ON for receiving alarms when no readings!", comment: "Body of confirmation"),
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
