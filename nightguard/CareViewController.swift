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
    
    fileprivate var reason: String = ""
    fileprivate var duration: Int = 60
    fileprivate var target: Int = 100
    
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
                    row.title = NSLocalizedString("Reason", comment: "Label for the Temporary Target Reason")
                    row.options = ["Activity", "Too High", "Too Low", "Meal Soon"]
                    row.value = "Activity"
                    self.reason = row.value!
                }.onChange { row in
                    self.reason = row.value!
                }
            
                <<< PickerInlineRow<Int>() { row in
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
                    row.options = [30, 60, 90, 120, 180]
                    row.value = 60
                    self.duration = row.value!
                }.onChange { row in
                    self.duration = row.value!
                }
        
                <<< PickerInlineRow<Int>() { row in
                    row.title = NSLocalizedString("Target Value", comment: "Label for Temporary Target Value")
                    row.options = [70, 80, 100, 120]
                    row.value = 70
                    self.target = row.value!
                }.onChange { row in
                    self.target = row.value!
                }
        
                <<< ButtonRow() { row in
                    row.title = NSLocalizedString("Set Target", comment: "Button to activate the Temporary Target")
                }.onCellSelection { _, _ in
                    let alertController = UIAlertController(title: "Set Target", message: "Do you want to set a temporary target to \(self.target) for \(self.duration) minutes?", preferredStyle: .alert)
                        let actionAccept = UIAlertAction(title: NSLocalizedString("Accept", comment: "Popup Accept-Button"), style: .default, handler: { (alert: UIAlertAction!) in
                            
                            NightscoutService.singleton.createTemporaryTarget(
                                reason: self.reason,
                                target: self.target,
                                durationInMinutes: self.duration,
                                resultHandler: {(error: String?) in
                                
                                if (error == nil) {
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
            
                +++ Section(header: NSLocalizedString("Delete an active Temporary Target", comment: "Section to delete a temporary Target"), footer: nil)
                <<< ButtonRow() { row in
                        row.title = NSLocalizedString("Delete Temporary Target", comment: "Button to delete a current Temporary Target")
                    }.onChange { row in
                        guard let value = row.value else { return }
                }
    }
}
