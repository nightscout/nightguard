//
//  AlarmViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 2/2/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka
import Foundation

class AlarmViewController: CustomFormViewController {
    
    var aboveSliderRow: SliderRow!
    var belowSliderRow: SliderRow!
        
    fileprivate let MAX_ALERT_ABOVE_VALUE : Float = 280
    fileprivate let MIN_ALERT_ABOVE_VALUE : Float = 80
    
    fileprivate let MAX_ALERT_BELOW_VALUE : Float = 200
    fileprivate let MIN_ALERT_BELOW_VALUE : Float = 50
    
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
        
        aboveSliderRow = SliderRow.glucoseLevelSlider(initialValue: AlarmRule.alertIfAboveValue.value, minimumValue: MIN_ALERT_ABOVE_VALUE, maximumValue: MAX_ALERT_ABOVE_VALUE)
        aboveSliderRow.cell.slider.addTarget(self, action: #selector(onSliderValueChanged(slider:event:)), for: .valueChanged)
        
        belowSliderRow = SliderRow.glucoseLevelSlider(initialValue: AlarmRule.alertIfBelowValue.value, minimumValue: MIN_ALERT_BELOW_VALUE, maximumValue: MAX_ALERT_BELOW_VALUE)
        belowSliderRow.cell.slider.addTarget(self, action: #selector(onSliderValueChanged(slider:event:)), for: .valueChanged)
        
        form
            +++ Section(header: "", footer: NSLocalizedString("Deactivate all alerts. This is NOT recommended. You will get no alarms or notifications at all anymore!", comment: "Footer for disable all alerts switch."))
            <<< SwitchRow("disableAllAlertsRow") { row in
                row.title = NSLocalizedString("Disable all alerts", comment: "Label for disable all alerts")
                row.value = AlarmRule.areAlertsGenerallyDisabled.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                
                if !value {
                    // setting to enabled is ok
                    AlarmRule.areAlertsGenerallyDisabled.value = value
                    return
                }
                
                // disabling alerts is critical. So show a popup:
                self?.showYesNoAlert(
                    title: NSLocalizedString("ARE YOU SURE?", comment: "Title for confirmation"),
                    message: NSLocalizedString("It is not recommended to disable all alerts! Do you really want to disable all alerts?", comment: "Alert popup body text for disabling all alerts"),
                    yesHandler: {
                        AlarmRule.areAlertsGenerallyDisabled.value = value
                },
                    noHandler: {
                        row.value = false
                        row.updateCell()
                })
            }
            
            +++ Section(header: NSLocalizedString("High BG Alert", comment: "Alarm settings title: High alert"), footer: NSLocalizedString("Alerts when the blood glucose raises above this value.", comment: "Footer for High alert")) { section in
                                section.hidden = Condition.function(["disableAllAlertsRow"], { form in
                    return (form.rowBy(tag: "disableAllAlertsRow") as? SwitchRow)?.value ?? false
                })
            } <<< aboveSliderRow
            
            +++ Section(header: NSLocalizedString("Low BG Alert", comment: "Alarm settings title: Low alert"), footer: NSLocalizedString("Alerts when the blood glucose drops below this value.", comment: "Footer for Low alert")) { section in
                                section.hidden = Condition.function(["disableAllAlertsRow"], { form in
                    return (form.rowBy(tag: "disableAllAlertsRow") as? SwitchRow)?.value ?? false
                })
            } <<< belowSliderRow
            
            +++ Section(NSLocalizedString("Other Alerts", comment: "Alarm settings title: Other alerts")) { section in
                                section.hidden = Condition.function(["disableAllAlertsRow"], { form in
                    return (form.rowBy(tag: "disableAllAlertsRow") as? SwitchRow)?.value ?? false
                })
            }
            
            <<< ButtonRowWithDynamicDetails(NSLocalizedString("Missed Readings", comment: "Alarm settings title: Missed readings")) { row in
                row.controllerProvider = { return MissedReadingsViewController() }
                row.detailTextProvider = {
                    if AlarmRule.noDataAlarmEnabled.value {
                        if #available(iOS 11.0, *) {
                            return String(format: NSLocalizedString("Alerts when no data for more than %d minutes.", comment: "Footer for missed readings alert"), AlarmRule.minutesWithoutValues.value)
                        } else {
                            // single line, as iOS 10 doesn't expand cell for more lines
                            return String(format: NSLocalizedString("%d minutes.", comment: "Single line footer for missed readings alert"), AlarmRule.minutesWithoutValues.value)
                        }
                    } else {
                        return NSLocalizedString("Off", comment: "Alert off")
                    }
                }
            }

            <<< ButtonRowWithDynamicDetails(NSLocalizedString("Fast Rise/Drop", comment: "Label for Fast rise/drop")) { row in
                row.controllerProvider = { return FastRiseDropViewController() }
                row.detailTextProvider = {
                    if AlarmRule.isEdgeDetectionAlarmEnabled.value {
                        
                        let deltaInMgdl = AlarmRule.deltaAmount.value
                        let delta = UnitsConverter.toDisplayUnits("\(deltaInMgdl)")
                        let units = UserDefaultsRepository.units.value.description
                        let consecutiveValue = AlarmRule.numberOfConsecutiveValues.value
                        
                        if #available(iOS 11.0, *) {
                            return String(format: NSLocalizedString(
                                "Alerts when BG values are rising or dropping with %@ %@, considering the last %d consecutive readings.",
                                comment: "Footer for Fast rise/drop"), delta, units, consecutiveValue)
                        } else {
                            // single line, as iOS 10 doesn't expand cell for more lines
                            return String(format: NSLocalizedString("%@ %@ in %d consecutive readings",
                                     comment: "Single line footer for Fast rise/drop"), delta, units, consecutiveValue)
                        }
                    } else {
                        return NSLocalizedString("Off", comment: "Alert off")
                    }
                }
            }
            
            <<< ButtonRowWithDynamicDetails(NSLocalizedString("Persistent High", comment: "Alarm settings title: Persistent High")) { row in
                row.controllerProvider = { return PersistentHighViewController() }
                row.detailTextProvider = {
                    
                    let urgentHighInMgdl = AlarmRule.persistentHighUpperBound.value
                    let urgentHigh = UnitsConverter.toDisplayUnits("\(urgentHighInMgdl)")
                    let units = UserDefaultsRepository.units.value.description
                    let urgentHighWithUnits = "\(urgentHigh) \(units)"
                    
                    if AlarmRule.isPersistentHighEnabled.value {
                        if #available(iOS 11.0, *) {
                            return String(format: NSLocalizedString(
                                "Alerts when BG remains high for more than %d minutes or exceeds the urgent high value %d).",
                                comment: "footer for Persistent high"), AlarmRule.persistentHighMinutes.value, urgentHighWithUnits)
                        } else {
                            // single line, as iOS 10 doesn't expand cell for more lines
                            return String(format: NSLocalizedString("%d minutes < %d).", comment: "Single line footer for Persistent high"), AlarmRule.persistentHighMinutes.value, urgentHighWithUnits)
                        }
                    } else {
                        return NSLocalizedString("Off", comment: "Alert off")
                    }
                }
            }
            
            <<< ButtonRowWithDynamicDetails(NSLocalizedString("Low Prediction", comment: "Alarm settings title: Low prediction")) { row in
                row.controllerProvider = { return LowPredictionViewController() }
                row.detailTextProvider = {
                    if AlarmRule.isLowPredictionEnabled.value {
                        if #available(iOS 11.0, *) {
                            return String(format: NSLocalizedString("Alerts when a low BG value is predicted in less than %d minutes.", comment: "Footer for predicted low"), AlarmRule.minutesToPredictLow.value)
                        } else {
                            // single line, as iOS 10 doesn't expand cell for more lines
                            return String(format: NSLocalizedString("%d minutes", comment: "Single line footer for predicted low"), AlarmRule.minutesToPredictLow.value)
                        }
                    } else {
                        return NSLocalizedString("Off", comment: "Alert off")
                    }
                }
            }
            
            +++ Section(header: "", footer: NSLocalizedString("Snooze (do not alert) when values are high or low but the trend is going in the right direction.", comment: "Footer for smart snooze switch")) { section in
                                section.hidden = Condition.function(["disableAllAlertsRow"], { form in
                    return (form.rowBy(tag: "disableAllAlertsRow") as? SwitchRow)?.value ?? false
                })
            }
            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Smart Snooze", comment: "Label for Smart snooze switch")
                row.value = AlarmRule.isSmartSnoozeEnabled.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmRule.isSmartSnoozeEnabled.value = value
            }
            
            +++ Section(header: "", footer: NSLocalizedString("When the application is in background, you can enable alert notifications to draw your attention when an alarm was activated.  Just to be sure that you will not miss the notifications, turn the volume up and disable the Do Not Disturb/Silence mode.", comment: "Footer for Alert notifications")) { section in
                                section.hidden = Condition.function(["disableAllAlertsRow"], { form in
                    return (form.rowBy(tag: "disableAllAlertsRow") as? SwitchRow)?.value ?? false
                })
            }
            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Alert Notifications", comment: "Label for Alert Notifications");
                row.value = AlarmNotificationService.singleton.enabled
                }.onChange { row in
                    guard let value = row.value else { return }
                    AlarmNotificationService.singleton.enabled = value
            }
            
            +++ Section() { section in
                                section.hidden = Condition.function(["disableAllAlertsRow"], { form in
                    return (form.rowBy(tag: "disableAllAlertsRow") as? SwitchRow)?.value ?? false
                })
            }
            <<< ButtonRowWithDynamicDetails(NSLocalizedString("Alert Volume", comment: "Label for Alert volume")) { row in
                row.controllerProvider = { return AlertVolumeViewController()
                }
            }
            <<< ButtonRowWithDynamicDetails(NSLocalizedString("Snoozing Actions", comment: "Label for Snoozing actions")) { row in
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
