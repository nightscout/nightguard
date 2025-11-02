//
//  PersistentHighViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 3/28/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

class PersistentHighViewController: CustomFormViewController {
    
    var urgentHighSliderRow: SliderRow!
    
    fileprivate let alarmOptions = [15, 20, 30, 45, 60, 90, 120]
    private var selectableSection: SelectableSection<ListCheckRow<Int>>!
    
    override func constructForm() {
        
        selectableSection = SelectableSection<ListCheckRow<Int>>(NSLocalizedString("Alert when high BG for more than", comment: "Label for duration options"), selectionType: .singleSelection(enableDeselection: true))
        selectableSection.onSelectSelectableRow = { cell, row in
            guard let value = row.value else { return }
            AlarmRule.persistentHighMinutes.value = value
        }
        selectableSection.hidden = "$PersistentHighSwitch == false"
        
        for option in alarmOptions {
            selectableSection <<< ListCheckRow<Int>("\(option) Minutes") { lrow in
                lrow.title = "\(option) " + NSLocalizedString("Minutes", comment: "Option")
                lrow.selectableValue = option
                lrow.value = (option == AlarmRule.persistentHighMinutes.value) ? option : nil
            }
        }
        
        urgentHighSliderRow = SliderRow.glucoseLevelSlider(
            initialValue: UnitsConverter.mgdlToDisplayUnits(AlarmRule.persistentHighUpperBound.value),
                minimumValue: UnitsConverter.mgdlToDisplayUnits(AlarmRule.alertIfAboveValue.value),
                maximumValue: UnitsConverter.mgdlToDisplayUnits(300))
            .onChange { row in
                guard let value = row.value else { return }
                let mgdlValue = UnitsConverter.displayValueToMgdl(value)
                
                print("Changed (persistent) urgent high slider to \(value) \(UserDefaultsRepository.units.value.description). \(mgdlValue) in mg/dl.")
                AlarmRule.persistentHighUpperBound.value = mgdlValue
        }
        
        let urgentHighSection = Section(header: NSLocalizedString("Urgent High", comment: "Label for Urgent High"), footer: NSLocalizedString("Alerts anytime when the blood glucose raises above this value.", comment: "Footer for Urgent High"))
        urgentHighSection <<< urgentHighSliderRow
        urgentHighSection.hidden = "$PersistentHighSwitch == false"

        
        form +++ Section(header: "", footer: NSLocalizedString("Alerts when the BG remains high for a longer period. When on, this alert will delay the high BG alert until the period elapsed or until reaching a maximum BG level (urgent high).", comment: "Footer for Persistent High"))
            <<< SwitchRow("PersistentHighSwitch") { row in
                row.title = NSLocalizedString("Persistent High", comment: "Alarm settings title: Persistent High")
                row.value = AlarmRule.isPersistentHighEnabled.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmRule.isPersistentHighEnabled.value = value
            }
            
            +++ selectableSection
            +++ urgentHighSection
    }

}
