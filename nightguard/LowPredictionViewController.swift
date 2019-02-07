//
//  LowPredictionViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 2/7/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

class LowPredictionViewController: CustomFormViewController {
    
    private let lowPredictionAlarmOptions = [5, 10, 15, 20, 25, 30]
    private var selectableSection: SelectableSection<ListCheckRow<Int>>!
    
    override func constructForm() {
        
        selectableSection = SelectableSection<ListCheckRow<Int>>("Prediction interval", selectionType: .singleSelection(enableDeselection: true))
        selectableSection.onSelectSelectableRow = { cell, row in
            guard let value = row.value else { return }
            AlarmRule.minutesToPredictLow.value = value
        }
        selectableSection.hidden = .function(["Low Prediction"], { form -> Bool in
            let row: RowOf<Bool>! = form.rowBy(tag: "Low Prediction")
            return row.value ?? false == false
        })
        
        for option in lowPredictionAlarmOptions {
            selectableSection <<< ListCheckRow<Int>("\(option) Minutes") { lrow in
                lrow.title = "\(option) Minutes"
                lrow.selectableValue = option
                lrow.value = (option == AlarmRule.minutesToPredictLow.value) ? option : nil
            }
        }
        
        form +++ Section(header: "", footer: "Alerts when a low BG value is predicted in the near future (if the current trend is continued).")
            <<< SwitchRow("Low Prediction") { row in
                row.title = "Low Prediction"
                row.value = AlarmRule.isLowPredictionEnabled.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmRule.isLowPredictionEnabled.value = value
            }
            
            +++ selectableSection
    }
}
