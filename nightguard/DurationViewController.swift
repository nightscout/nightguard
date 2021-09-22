//
//  TimerViewController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 28.08.21.
//  Copyright © 2021 private. All rights reserved.
//

import Foundation

import UIKit
import Eureka

class DurationViewController: CustomFormViewController {
    
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
        
        form
            
        +++ Section(header: NSLocalizedString("Cannula", comment: "Cannula Row Header"), footer: NSLocalizedString("Set the time when you changed your cannula. This will be displayed on the main screen as CAGE. Keep in mind that you just can reduce this date.", comment: "Footer for Cannula Change Date"))
        
            <<< DateTimeRow() { row in
                row.title = NSLocalizedString("Cannula change date", comment: "Label for Cannula Change Time")
                row.tag = "cannulaChangeDate"
                row.value = NightscoutCacheService.singleton.getCannulaChangeTime()
            }
            
            <<< ButtonRow() { row in
                row.title = NSLocalizedString("Reset", comment: "Button to reset the Cannula Change Date")
            }.onCellSelection { _, _ in
                
                let dateTimeRow = (self.form.rowBy(tag: "cannulaChangeDate") as? DateTimeRow)
                dateTimeRow?.value = Date()
                dateTimeRow?.reload()
            }
            
            <<< ButtonRow() { row in
                row.title = NSLocalizedString("Save", comment: "Button to activate the Cannula Change Date")
            }.onCellSelection { _, _ in
                
                let changeDate = (self.form.rowBy(tag: "cannulaChangeDate") as? DateTimeRow)?.value ?? Date()
                self.displayModifyChangeDatePopup(title: NSLocalizedString("Modify Cannula Change Date", comment: "Modify Cannula Change Date Popup Title"), changeDate: changeDate) {
                    NightscoutService.singleton.createCannulaChangeTreatment(changeDate: changeDate, resultHandler: {(error: String?) in
                            
                            if (error != nil) {
                                self.displayErrorMessagePopup(message: error!)
                            } else {
                                NightscoutDataRepository.singleton.storeCannulaChangeTime(cannulaChangeTime: changeDate)
                                UIApplication.shared.showMain()
                            }
                    })
                }
            }
        
        +++ Section(header: NSLocalizedString("Sensor", comment: "Sensor Row Header"), footer: NSLocalizedString("Set the time when you changed your sensor. This will be displayed on the main screen as SAGE. Keep in mind that you just can reduce this date.", comment: "Footer for Sensor"))
       
            <<< DateTimeRow() { row in
                row.title = NSLocalizedString("Sensor change date", comment: "Label for Sensor Change Time")
                row.tag = "sensorChangeDate"
                row.value = NightscoutCacheService.singleton.getSensorChangeTime()
            }
            
            <<< ButtonRow() { row in
                row.title = NSLocalizedString("Reset", comment: "Button to reset the Change Date")
            }.onCellSelection { _, _ in
                
                let dateTimeRow = (self.form.rowBy(tag: "sensorChangeDate") as? DateTimeRow)
                dateTimeRow?.value = Date()
                dateTimeRow?.reload()
            }
            
            <<< ButtonRow() { row in
                row.title = NSLocalizedString("Save", comment: "Button to activate the new Change Date")
            }.onCellSelection { _, _ in
                
                let changeDate = (self.form.rowBy(tag: "sensorChangeDate") as? DateTimeRow)?.value ?? Date()
                self.displayModifyChangeDatePopup(title: NSLocalizedString("Modify Sensor Change Date", comment: "Modify Sensor Change Date Popup Title"), changeDate: changeDate) {
                    NightscoutService.singleton.createSensorChangeTreatment(changeDate: changeDate, resultHandler: {(error: String?) in
                            
                            if (error != nil) {
                                self.displayErrorMessagePopup(message: error!)
                            } else {
                                NightscoutDataRepository.singleton.storeSensorChangeTime(sensorChangeTime: changeDate)
                                self.playSuccessFeedback()
                                UIApplication.shared.showMain()
                            }
                    })
                }
            }
        
        +++ Section(header: NSLocalizedString("Battery", comment: "Battery Row Header"), footer: NSLocalizedString("Set the time when you changed your pump battery. This will be displayed on the main screen as BAGE. Keep in mind that you just can reduce this date.", comment: "Footer for Battery"))
       
            <<< DateTimeRow() { row in
                row.title = NSLocalizedString("Battery change date", comment: "Label for Battery Change Time")
                row.tag = "batteryChangeDate"
                row.value = NightscoutCacheService.singleton.getPumpBatteryChangeTime()
            }
        
            <<< ButtonRow() { row in
                row.title = NSLocalizedString("Reset", comment: "Button to reset the Change Date")
            }.onCellSelection { _, _ in
                
                let dateTimeRow = (self.form.rowBy(tag: "batteryChangeDate") as? DateTimeRow)
                dateTimeRow?.value = Date()
                dateTimeRow?.reload()
            }
            
            <<< ButtonRow() { row in
                row.title = NSLocalizedString("Save", comment: "Button to activate the new Change Date")
            }.onCellSelection { _, _ in
                
                let changeDate = (self.form.rowBy(tag: "batteryChangeDate") as? DateTimeRow)?.value ?? Date()
                self.displayModifyChangeDatePopup(title: NSLocalizedString("Modify Battery Change Date", comment: "Modify Battery Change Date Popup Title"), changeDate: changeDate) {
                    NightscoutService.singleton.createBatteryChangeTreatment(changeDate: changeDate, resultHandler: {(error: String?) in
                            
                            if (error != nil) {
                                self.displayErrorMessagePopup(message: error!)
                            } else {
                                NightscoutDataRepository.singleton.storeBatteryChangeTime(batteryChangeTime: changeDate)
                                self.playSuccessFeedback()
                                UIApplication.shared.showMain()
                            }
                    })
                }
            }
    }
    
    fileprivate func displayModifyChangeDatePopup(title : String, changeDate : Date, successHandler: @escaping () -> Void) {

        let alertController = UIAlertController(
            title: title,
            message: NSLocalizedString("Do you want to modify the change date to ", comment: "Cancel Target Popup Text")
                + changeDate.toDateTimeString() + "?",
            preferredStyle: .alert)
        let actionAccept = UIAlertAction(title: NSLocalizedString("Accept", comment: "Popup Accept-Button"), style: .default, handler: { (alert: UIAlertAction!) in
            
            successHandler()
        })
        let actionDecline = UIAlertAction(title: NSLocalizedString("Decline", comment: "Popup Decline-Button"), style: .default, handler: { (alert: UIAlertAction!) in
        })
        alertController.addAction(actionAccept)
        alertController.addAction(actionDecline)
        self.present(alertController, animated: true, completion: nil)
    }
}
