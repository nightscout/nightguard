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
        
        selectableSection = SelectableSection<ListCheckRow<Int>>(NSLocalizedString("Prediction interval", comment: "Label for prediction interval options"), selectionType: .singleSelection(enableDeselection: true))
        selectableSection.onSelectSelectableRow = { cell, row in
            guard let value = row.value else { return }
            AlarmRule.minutesToPredictLow.value = value
        }
        selectableSection.hidden = .function(["Low Prediction"], { form -> Bool in
            let row: RowOf<Bool>! = form.rowBy(tag: "Low Prediction")
            return row.value ?? false == false
        })
        
        for option in lowPredictionAlarmOptions {
            let optionString = String(format: NSLocalizedString("%d Minutes", comment: "Option in low predicion alert settings"), option)

            selectableSection <<< ListCheckRow<Int>(optionString) { lrow in
                lrow.title = optionString
                lrow.selectableValue = option
                lrow.value = (option == AlarmRule.minutesToPredictLow.value) ? option : nil
            }
        }
        
        form +++ Section(header: "", footer: NSLocalizedString("Alerts when a low BG value is predicted in the near future (if the current trend is continued).", comment: "Footer in low predicion alert settings"))
            <<< SwitchRow("Low Prediction") { row in
                row.title = NSLocalizedString("Low Prediction2", comment: "Title in low predicion alert settings")
                row.value = AlarmRule.isLowPredictionEnabled.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmRule.isLowPredictionEnabled.value = value
            }
            
            +++ selectableSection
    }
}
