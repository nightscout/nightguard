//
//  FastRiseDropViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 2/7/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

class FastRiseDropViewController: CustomFormViewController {
    
    override func constructForm() {
        
        form +++ Section(header: "", footer: NSLocalizedString("Alerts when a fast BG rise or drop is detected in the last consecutive readings.", comment: "Footer for Alerts"))
            <<< SwitchRow("FastRiseDropSwitch") { row in
                row.title = NSLocalizedString("Fast Rise/Drop", comment: "Label for Fast rise/drop")
                row.value = AlarmRule.isEdgeDetectionAlarmEnabled.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmRule.isEdgeDetectionAlarmEnabled.value = value
            }
            
            +++ Section(footer: NSLocalizedString("How many consecutive readings to consider.", comment: "Footer for consecutive readings")) { header in
                header.hidden = "$FastRiseDropSwitch == false"
            }
            
            <<< SegmentedRow<Int>() { row in
                row.title = NSLocalizedString("Consecutive Readings", comment: "Label for Consecutive Readings")
                row.options = [2, 3, 4, 5]
                row.value = AlarmRule.numberOfConsecutiveValues.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmRule.numberOfConsecutiveValues.value = Int(value)
                }
            
            +++ Section(footer: NSLocalizedString("The difference (delta) between two individual readings.", comment: "Footer for delta")) { header in
                header.hidden = "$FastRiseDropSwitch == false"
            }
            
            <<< StepperRow() { row in
                row.title = NSLocalizedString("Delta", comment: "Label for delta")
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    let cleanValue = Float(value).cleanValue
                    return "\(cleanValue) \(UserDefaultsRepository.units.value.description)"
                }
                
                }.cellSetup { cell, row in
                    row.value = Double(UnitsConverter.toDisplayUnits("\(AlarmRule.deltaAmount.value)"))!
                    
                    let mmolUnits = (UserDefaultsRepository.units.value == .mmol)
                    cell.stepper.stepValue = mmolUnits ? 0.1 : 1
                    cell.stepper.minimumValue = mmolUnits ? 0.1 : 1
                    cell.stepper.maximumValue = mmolUnits ? 2.0 : 36

                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmRule.deltaAmount.value = UnitsConverter.toMgdl(Float(value))
                    print(AlarmRule.deltaAmount.value)
        }
    }
}
