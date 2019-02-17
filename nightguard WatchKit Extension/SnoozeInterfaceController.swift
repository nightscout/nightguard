//
//  SnoozeInterfaceController.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 10.02.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import WatchKit

class SnoozeInterfaceController : WKInterfaceController {
    
    @IBAction func doSnooze30Minutes() {
        AlarmRule.snooze(30)
        self.dismiss()
    }
    
    @IBAction func doSnooze1Hour() {
        AlarmRule.snooze(60)
        self.dismiss()
    }
    
    @IBAction func doSnooze2Hours() {
        AlarmRule.snooze(120)
        self.dismiss()
    }
    
    @IBAction func doSnooze3Hours() {
        AlarmRule.snooze(180)
        self.dismiss()
    }
    
    @IBAction func doSnooze6Hours() {
        AlarmRule.snooze(60 * 6)
        self.dismiss()
    }
    
    @IBAction func doSnooze1Day() {
        AlarmRule.snooze(60 * 24)
        self.dismiss()
    }
    
    @IBAction func doCancelSnoozeAction() {
        AlarmRule.disableSnooze()
        self.dismiss()
    }
}
