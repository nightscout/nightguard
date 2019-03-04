//
//  AlarmViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 2/2/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

class AlarmViewController: CustomFormViewController {
    
    var aboveSliderRow: SliderRow!
    var belowSliderRow: SliderRow!
        
    fileprivate let MAX_ALERT_ABOVE_VALUE : Float = 280
    fileprivate let MIN_ALERT_ABOVE_VALUE : Float = 80
    
    fileprivate let MAX_ALERT_BELOW_VALUE : Float = 200
    fileprivate let MIN_ALERT_BELOW_VALUE : Float = 50
    
    fileprivate let SNAP_INCREMENT : Float = 10 // or change it to 5?
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }

    override var reconstructFormOnViewWillAppear: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    override func constructForm() {
        
        aboveSliderRow = createSliderRow(initialValue: AlarmRule.alertIfAboveValue.value, minimumValue: MIN_ALERT_ABOVE_VALUE, maximumValue: MAX_ALERT_ABOVE_VALUE)
        aboveSliderRow.cell.slider.addTarget(self, action: #selector(onSliderValueChanged(slider:event:)), for: .valueChanged)
        
        belowSliderRow = createSliderRow(initialValue: AlarmRule.alertIfBelowValue.value, minimumValue: MIN_ALERT_BELOW_VALUE, maximumValue: MAX_ALERT_BELOW_VALUE)
        belowSliderRow.cell.slider.addTarget(self, action: #selector(onSliderValueChanged(slider:event:)), for: .valueChanged)
        
        
        form +++ Section(header: "High BG Alert", footer: "Alerts when the blood glucose raises above this value.") <<< aboveSliderRow
            
            +++ Section(header: "Low BG Alert", footer: "Alerts when the blood glucose drops below this value.") <<< belowSliderRow
            
            +++ Section("Other Alerts")
            
            <<< ButtonRowWithDynamicDetails("Missed Readings") { row in
                row.controllerProvider = { return MissedReadingsViewController() }
                row.detailTextProvider = {
                    if AlarmRule.noDataAlarmEnabled.value {
                        if #available(iOS 11.0, *) {
                            return "Alerts when no data for more than \(AlarmRule.minutesWithoutValues.value) minutes."
                        } else {
                            // single line, as iOS 10 doesn't expand cell for more lines
                            return "\(AlarmRule.minutesWithoutValues.value) minutes"
                        }
                    } else {
                        return "Off"
                    }
                }
            }

            <<< ButtonRowWithDynamicDetails("Fast Rise/Drop") { row in
                row.controllerProvider = { return FastRiseDropViewController() }
                row.detailTextProvider = {
                    if AlarmRule.isEdgeDetectionAlarmEnabled.value {
                        
                        let deltaInMgdl = AlarmRule.deltaAmount.value
                        let delta = UnitsConverter.toDisplayUnits("\(deltaInMgdl)")
                        let units = UserDefaultsRepository.units.value.description
                        
                        if #available(iOS 11.0, *) {
                            return "Alerts when BG values are rising or dropping with \(delta) \(units), considering the last \(AlarmRule.numberOfConsecutiveValues.value) consecutive readings."
                        } else {
                            // single line, as iOS 10 doesn't expand cell for more lines
                            return "\(delta) \(units) in \(AlarmRule.numberOfConsecutiveValues.value) consecutive readings"
                        }
                    } else {
                        return "Off"
                    }
                }
            }
            
            <<< ButtonRowWithDynamicDetails("Low Prediction") { row in
                row.controllerProvider = { return LowPredictionViewController() }
                row.detailTextProvider = {
                    if AlarmRule.isLowPredictionEnabled.value {
                        if #available(iOS 11.0, *) {
                            return "Alerts when a low BG value is predicted in less than \(AlarmRule.minutesToPredictLow.value) minutes."
                        } else {
                            // single line, as iOS 10 doesn't expand cell for more lines
                            return "\(AlarmRule.minutesToPredictLow.value) minutes"
                        }
                    } else {
                        return "Off"
                    }
                }
            }
            
            +++ Section(header: "", footer: "Snooze (do not alert) when values are high or low but the trend is going in the right direction.")
            <<< SwitchRow() { row in
                row.title = "Smart Snooze"
                row.value = AlarmRule.isSmartSnoozeEnabled.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmRule.isSmartSnoozeEnabled.value = value
            }
            
            +++ Section(header: "", footer: "When the application is in background, you can enable alert notifications to draw your attention when an alarm was activated.  Just to be sure that you will not miss the notifications, turn the volume up and disable the Do Not Disturb/Silence mode.")
            <<< SwitchRow() { row in
                row.title = "Alert Notifications"
                row.value = AlarmNotificationService.singleton.enabled
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmNotificationService.singleton.enabled = value
            }
            
            +++ Section()
            <<< ButtonRowWithDynamicDetails("Alert Volume") { row in
                row.controllerProvider = { return AlertVolumeViewController()
                }
            }
            <<< ButtonRowWithDynamicDetails("Snoozing Actions") { row in
                row.controllerProvider = { return SnoozeActionsViewController()
                }
        }
    }
    
    @objc func onSliderValueChanged(slider: UISlider, event: UIEvent) {
        guard let touchEvent = event.allTouches?.first else { return }
        
        // modify UserDefaultsValue ONLY when slider value change events ended
        switch touchEvent.phase {
        case .ended:
            if slider === aboveSliderRow.cell.slider {
                
                guard let value = aboveSliderRow.value else { return }
                let mgdlValue = UnitsConverter.toMgdl(value)
                
                guard mgdlValue > UserDefaultsRepository.lowerBound.value else {
                    alertInvalidChange(message: "High BG value should be above low BG value!")
                    updateSliderRowsFromUserDefaultsValues()
                    return
                }
                
                print("Changed above slider to \(mgdlValue) \(UserDefaultsRepository.units.value.description)")
                UserDefaultsRepository.upperBound.value = mgdlValue
                
            } else if slider === belowSliderRow.cell.slider {
                
                guard let value = belowSliderRow.value else { return }
                let mgdlValue = UnitsConverter.toMgdl(value)
                
                guard mgdlValue < UserDefaultsRepository.upperBound.value else {
                    alertInvalidChange(message: "Low BG value should be below high BG value!")
                    updateSliderRowsFromUserDefaultsValues()
                    return
                }
                
                print("Changed below slider to \(mgdlValue) \(UserDefaultsRepository.units.value.description)")
                UserDefaultsRepository.lowerBound.value = mgdlValue
            }
            
        default:
            break
        }
    }
    
    private func createSliderRow(initialValue: Float, minimumValue: Float, maximumValue: Float) -> SliderRow {
        
        return SliderRow() { row in
            row.value = Float(UnitsConverter.toDisplayUnits("\(initialValue)"))!
            }.cellSetup { [weak self] cell, row in
                guard let self = self else { return }
                //                    row.shouldHideValue = true
                
                let minimumValue = Float(UnitsConverter.toDisplayUnits("\(minimumValue)"))!
                let maximumValue = Float(UnitsConverter.toDisplayUnits("\(maximumValue)"))!
                let snapIncrement = (UserDefaultsRepository.units.value == .mgdl) ? self.SNAP_INCREMENT : 0.1
                
                let steps = (maximumValue - minimumValue) / snapIncrement
                row.steps = UInt(steps.rounded())
                cell.slider.minimumValue = minimumValue
                cell.slider.maximumValue = maximumValue
                row.displayValueFor = { value in
                    guard let value = value else { return "" }
                    let units = UserDefaultsRepository.units.value.description
                    return String("\(value.cleanValue) \(units)")
                }
                
                // fixed width for value label
                let widthConstraint = NSLayoutConstraint(item: cell.valueLabel, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 96)
                cell.valueLabel.addConstraints([widthConstraint])
        }
    }
    
    private func alertInvalidChange(message: String) {
        let alertController = UIAlertController(title: "Invalid change", message: message, preferredStyle: .alert)
        let actionOk = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(actionOk)
        present(alertController, animated: true, completion: nil)
    }
    
    private func updateSliderRowsFromUserDefaultsValues() {
        aboveSliderRow.value = Float(UnitsConverter.toDisplayUnits("\(AlarmRule.alertIfAboveValue.value)"))!
        aboveSliderRow.updateCell()
        belowSliderRow.value = Float(UnitsConverter.toDisplayUnits("\(AlarmRule.alertIfBelowValue.value)"))!
        belowSliderRow.updateCell()
    }
}
