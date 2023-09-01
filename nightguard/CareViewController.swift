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

class CareViewController: CustomFormViewController {
    
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
        
        form +++ Section(header: NSLocalizedString("Set a new Temporary Target", comment: "Label for Temporary Target Section"), footer: nil)
                
                <<< PickerInlineRow<String>() { row in
                    row.tag = "Reason"
                    row.title = NSLocalizedString("Reason", comment: "Label for the Temporary Target Reason")
                    row.options = ["Activity", "Too High", "Too Low", "Meal Soon"]
                    row.value = UserDefaultsRepository.temporaryTargetReason.value
                    row.displayValueFor = { value in
                        return NSLocalizedString(value!, comment: "")
                    }
                }.onChange { row in
                    UserDefaultsRepository.temporaryTargetReason.value = row.value!
                    self.restoreDefaultTargetValueFor(reason: row.value!)
                    self.restoreDefaultDurationFor(reason: row.value!)
                }
            
                <<< PickerInlineRow<Int>() { row in
                    row.tag = "Duration"
                    row.title = NSLocalizedString("Duration", comment: "Label for Temporary Target Duration")
                    row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        if value < 60 {
                            return "\(value) " + NSLocalizedString("minutes", comment: "Minutes TT Unit")
                        } else if value == 60 {
                            return "1 " + NSLocalizedString("hour", comment: "Hour TT Unit")
                        } else if value == 90 {
                            return "1.5 " + NSLocalizedString("hours", comment: "Hour TT Unit")
                        } else {
                            return "\(value / 60) " + NSLocalizedString("hours", comment: "Hour TT Unit")
                        }
                    }
                    row.options = [30, 60, 90, 120, 180, 360, 480, 600, 720]
                    row.value = UserDefaultsRepository.temporaryTargetDuration.value
                }.onChange { row in
                    UserDefaultsRepository.temporaryTargetDuration.value = row.value!
                    self.storeNewDefault(duration: row.value!)
                }
        
                <<< PickerInlineRow<Int>() { row in
                    row.tag = "Value"
                    row.title = NSLocalizedString("Target Value", comment: "Label for Temporary Target Value")
                    row.options = [72, 80, 100, 120, 145, 160]
                    row.value = UserDefaultsRepository.temporaryTargetAmount.value
                    row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return UnitsConverter.mgdlToDisplayUnits(String(describing: value))
                    }
                }.onChange { row in
                    UserDefaultsRepository.temporaryTargetAmount.value = row.value!
                    self.storeNewDefault(value: row.value!)
                }
        
                <<< ButtonRow() { row in
                    row.title = NSLocalizedString("Set Target", comment: "Button to activate the Temporary Target")
                }.onCellSelection { _, _ in
                    
                    self.displayActivateTemporaryTargetPopup()
                }
            
                +++ Section(header: NSLocalizedString("Delete an active Temporary Target", comment: "Section to delete a temporary Target"), footer: nil)
                <<< ButtonRow() { row in
                        row.title = NSLocalizedString("Delete Temporary Target", comment: "Button to delete a current Temporary Target")
                    }.onCellSelection { _, _ in
                        
                        self.displayCancelTargetPopup()
                }
        
                +++ Section(header: NSLocalizedString("Enter consumed Carbs", comment: "Section to enter Carbs"), footer: nil)
                <<< PickerInlineRow<Int>() { row in
                    row.tag = "Carbs"
                    row.title = NSLocalizedString("Gramms [g]", comment: "Label for the amount of carbs in gramm")
                    row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(value)g"
                    }
                    row.options = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100]
                    row.value = UserDefaultsRepository.carbs.value
                }.onChange { row in
                    UserDefaultsRepository.carbs.value = row.value!
                }
                <<< ButtonRow() { row in
                        row.title = NSLocalizedString("Add Carbs", comment: "Button to add consumed Carbs")
                    }.onCellSelection { _, _ in
                        
                        self.displayEnterCarbsPopup(carbs: UserDefaultsRepository.carbs.value)
                }
    }
    
    fileprivate func restoreDefaultTargetValueFor(reason: String) {
        
        let targetValueRow : PickerInlineRow<Int> = self.form.rowBy(tag: "Value") as! PickerInlineRow<Int>
        switch reason {
            case "Activity":
                targetValueRow.value = UserDefaultsRepository.temporaryTargetActivityDefaultAmount.value
            case "Too High":
                targetValueRow.value = UserDefaultsRepository.temporaryTargetTooHighDefaultAmount.value
            case "Too Low":
                targetValueRow.value = UserDefaultsRepository.temporaryTargetTooLowDefaultAmount.value
            default:
                targetValueRow.value =
                    UserDefaultsRepository.temporaryTargetMealSoonDefaultAmount.value
        }
        targetValueRow.reload()
    }
    
    fileprivate func restoreDefaultDurationFor(reason: String) {
        let targetValueRow : PickerInlineRow<Int> = self.form.rowBy(tag: "Duration") as! PickerInlineRow<Int>
        switch reason {
            case "Activity":
                targetValueRow.value = UserDefaultsRepository.temporaryTargetActivityDefaultDuration.value
            case "Too High":
                targetValueRow.value = UserDefaultsRepository.temporaryTargetTooHighDefaultDuration.value
            case "Too Low":
                targetValueRow.value = UserDefaultsRepository.temporaryTargetTooLowDefaultDuration.value
            default:
                targetValueRow.value =
                    UserDefaultsRepository.temporaryTargetMealSoonDefaultDuration.value
        }
        targetValueRow.reload()
    }
    
    fileprivate func storeNewDefault(duration: Int) {
        let reasonValueRow : PickerInlineRow<String> = self.form.rowBy(tag: "Reason") as! PickerInlineRow<String>
        let reason = reasonValueRow.value
        switch reason {
            case "Activity":
                UserDefaultsRepository.temporaryTargetActivityDefaultDuration.value = duration
            case "Too High":
                UserDefaultsRepository.temporaryTargetTooHighDefaultDuration.value = duration
            case "Too Low":
                UserDefaultsRepository.temporaryTargetTooLowDefaultDuration.value = duration
            default:
                UserDefaultsRepository.temporaryTargetMealSoonDefaultDuration.value = duration
        }
    }
    
    fileprivate func storeNewDefault(value: Int) {
        let reasonValueRow : PickerInlineRow<String> = self.form.rowBy(tag: "Reason") as! PickerInlineRow<String>
        let reason = reasonValueRow.value
        switch reason {
            case "Activity":
                UserDefaultsRepository.temporaryTargetActivityDefaultAmount.value = value
            case "Too High":
                UserDefaultsRepository.temporaryTargetTooHighDefaultAmount.value = value
            case "Too Low":
                UserDefaultsRepository.temporaryTargetTooLowDefaultAmount.value = value
            default:
                UserDefaultsRepository.temporaryTargetMealSoonDefaultAmount.value = value
        }
    }
    
    fileprivate func displayEnterCarbsPopup(carbs : Int) {

        let alertController = UIAlertController(
            title: NSLocalizedString("Add Carbs", comment: "Add Carbs Popup Title"),
            message: String(format: NSLocalizedString("Do you want to enter %dg of consumed carbs?", comment: "Cancel Target Popup Text"), carbs),
            preferredStyle: .alert)
        let actionAccept = UIAlertAction(title: NSLocalizedString("Accept", comment: "Popup Accept-Button"), style: .default, handler: { (alert: UIAlertAction!) in
            
            self.playSuccessFeedback()
            NightscoutService.singleton.createCarbsCorrection(carbs: carbs, resultHandler: {(error: String?) in
                    
                    if (error != nil) {
                        self.displayErrorMessagePopup(message: error!)
                    } else {
                        UIApplication.shared.showMain()
                    }
            })
        })
        let actionDecline = UIAlertAction(title: NSLocalizedString("Decline", comment: "Popup Decline-Button"), style: .default, handler: { (alert: UIAlertAction!) in
        })
        alertController.addAction(actionAccept)
        alertController.addAction(actionDecline)
        self.present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func displayCancelTargetPopup() {
        let alertController = UIAlertController(
            title: NSLocalizedString("Cancel Target", comment: "Cancel Target Popup Title"),
            message: NSLocalizedString("Do you want to cancel an active temporary target?", comment: "Cancel Target Popup Text"),
            preferredStyle: .alert)
        let actionAccept = UIAlertAction(title: NSLocalizedString("Accept", comment: "Popup Accept-Button"), style: .default, handler: { (alert: UIAlertAction!) in
            
            self.playSuccessFeedback()
            NightscoutService.singleton.deleteTemporaryTarget(
                resultHandler: {(error: String?) in
                    
                    if (error != nil) {
                        self.displayErrorMessagePopup(message: error!)
                    } else {
                        UIApplication.shared.showMain()
                    }
            })
        })
        let actionDecline = UIAlertAction(title: NSLocalizedString("Decline", comment: "Popup Decline-Button"), style: .default, handler: { (alert: UIAlertAction!) in
        })
        alertController.addAction(actionAccept)
        alertController.addAction(actionDecline)
        self.present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func displayActivateTemporaryTargetPopup() {
        let alertController = UIAlertController(
            title: String(format: NSLocalizedString("Set Target '%@'?", comment: "Set Target Message Title"), UserDefaultsRepository.temporaryTargetReason.value),
            message: String(format: NSLocalizedString("Do you want to set a temporary target for %d minutes?", comment: "Set Target Message Text"), UserDefaultsRepository.temporaryTargetDuration.value), preferredStyle: .alert)
        let actionAccept = UIAlertAction(title: NSLocalizedString("Accept", comment: "Popup Accept-Button"), style: .default, handler: { (alert: UIAlertAction!) in
            
            self.playSuccessFeedback()
            NightscoutService.singleton.createTemporaryTarget(
                reason: UserDefaultsRepository.temporaryTargetReason.value,
                target: UserDefaultsRepository.temporaryTargetAmount.value,
                durationInMinutes: UserDefaultsRepository.temporaryTargetDuration.value,
                resultHandler: {(error: String?) in
                    
                    if (error != nil) {
                        self.displayErrorMessagePopup(message: error!)
                        return
                    }
                    UIApplication.shared.showMain()
            })
        })
        let actionDecline = UIAlertAction(title: NSLocalizedString("Decline", comment: "Popup Decline-Button"), style: .default, handler: { (alert: UIAlertAction!) in
        })
        alertController.addAction(actionAccept)
        alertController.addAction(actionDecline)
        self.present(alertController, animated: true, completion: nil)
    }
}
