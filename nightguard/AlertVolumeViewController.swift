//
//  AlertVolumeViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 2/8/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

class AlertVolumeViewController: CustomFormViewController {
    
    override var reconstructFormOnViewWillAppear: Bool {
        return true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // stop testing the alarm
        if AlarmSound.isTesting {
            AlarmSound.isTesting = false
            AlarmSound.stop()
        }
    }
    
    override func constructForm() {
        
        form +++ Section(header: "Alert Volume", footer: "If overriding the system output volume, your custom volume level will be used rather than phone's current volume level.")
            <<< SwitchRow("OverrideSystemVolumeSwitch") { row in
                row.title = "Override System Volume"
                row.value = AlarmSound.overrideSystemOutputVolume.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmSound.overrideSystemOutputVolume.value = value
            }
            
            <<< SliderRow() { row in
                row.value = AlarmSound.systemOutputVolume.value
                row.shouldHideValue = true
                row.hidden = "$OverrideSystemVolumeSwitch == false"
                }
                .cellSetup { cell, row in
                    cell.slider.minimumValue = 0.0
                    cell.slider.maximumValue = 1.0
                    cell.slider.minimumValueImage = UIImage(named: "volume-low")?.withRenderingMode(.alwaysTemplate)
                    cell.slider.maximumValueImage = UIImage(named: "volume-high")?.withRenderingMode(.alwaysTemplate)
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmSound.systemOutputVolume.value = value
            }
            
            +++ Section(footer: "If selected, the alert will start quietly and increase the volume gradualy, reaching the maximum volume in selected time interval.")
            <<< PickerInlineRow<Int>() { row in
                row.title = "Progressive Volume"
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    if value == 0 {
                        return "Off"
                    } else if value < 60 {
                        return "\(value) seconds"
                    } else {
                        return "\(value / 60) minutes"
                    }
                }
                row.options = [0, 30, 60, 120, 300, 600, 900, 1200]
                row.value = Int(AlarmSound.fadeInTimeInterval.value)
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmSound.fadeInTimeInterval.value = TimeInterval(value)
            }
            
            +++ Section()
            <<< SwitchRow() { row in
                row.title = "Vibrate"
                row.value = AlarmSound.vibrate.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmSound.vibrate.value = value
            }
            
            +++ Section()
            <<< ButtonRow() { row in
                }.cellUpdate { cell, row in
                    if AlarmSound.isPlaying {
                        cell.textLabel?.text = "Stop Alert"
                        cell.textLabel?.textColor = UIColor.red
                    } else {
                        cell.textLabel?.text = "Test Alert"
                        cell.textLabel?.textColor = UIColor(netHex: 0x007AFF)  // default tint color - blue
                    }
                }.onCellSelection { cell, row in
                    AlarmSound.isTesting = true
                    if AlarmSound.isPlaying {
                        AlarmSound.stop()
                    } else {
                        AlarmSound.play()
                    }
                    
                    row.updateCell()
            }
    }
}
