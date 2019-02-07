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
        
        form +++ Section(header: "", footer: "Alerts when a fast BG rise or drop is detected in the last consecutive readings.")
            <<< SwitchRow("Fast Rise/Drop") { row in
                row.title = "Fast Rise/Drop"
                row.value = AlarmRule.isEdgeDetectionAlarmEnabled.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmRule.isEdgeDetectionAlarmEnabled.value = value
            }            
    }
}
