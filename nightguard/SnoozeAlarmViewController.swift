//
//  SnoozeAlarmViewController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 21.04.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import UIKit
import WidgetKit

class SnoozeAlarmViewController: UIViewController {
    
    @IBOutlet weak var stopSnoozingButton: UIButton!
    @IBOutlet weak var buttonHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // customize all buttons
        let buttons = self.view.subviews.filter { $0 is UIButton }
        buttons.forEach { button in
            button.layer.cornerRadius = 4
            button.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        }
        
        // customize sizes fos smaller devices
        switch DeviceSize() {
        case .iPhone4:
            buttonHeightConstraint.constant = 42
            buttons.forEach { ($0 as? UIButton)?.titleLabel?.font = UIFont.systemFont(ofSize: 28) }
            stopSnoozingButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        case .iPhone5:
            buttonHeightConstraint.constant = 56
            buttons.forEach { ($0 as? UIButton)?.titleLabel?.font = UIFont.systemFont(ofSize: 32) }
            stopSnoozingButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        default:
            break
        }

        // stop snoozing is a little different...
        stopSnoozingButton.backgroundColor = UIColor.white
        stopSnoozingButton.setTitleColor(UIColor.black, for: .normal)
        // ...and visible only if snoozed
        stopSnoozingButton.isHidden = !AlarmRule.isSnoozed()
    }
    
    @IBAction func do5minButtonPressed(_ sender: Any) {
        snoozeMinutes(5)
    }

    @IBAction func do10minButtonPressed(_ sender: Any) {
        snoozeMinutes(10)
    }

    @IBAction func do15minButtonPressed(_ sender: Any) {
        snoozeMinutes(15)
    }

    @IBAction func do20minButtonPressed(_ sender: Any) {
        snoozeMinutes(20)
    }
    
    @IBAction func do30minButtonPressed(_ sender: Any) {
        snoozeMinutes(30)
    }
    
    @IBAction func do45minButtonPressed(_ sender: Any) {
        snoozeMinutes(45)
    }
    
    @IBAction func do1hButtonPressed(_ sender: Any) {
        snoozeMinutes(60)
    }
    
    @IBAction func do2hButtonPressed(_ sender: Any) {
        snoozeMinutes(2 * 60)
    }
    
    @IBAction func do3hButtonPressed(_ sender: Any) {
        snoozeMinutes(3 * 60)
    }
    
    @IBAction func do6hButtonPressed(_ sender: Any) {
        snoozeMinutes(6 * 60)
    }
    
    @IBAction func do12hButtonPressed(_ sender: Any) {
        snoozeMinutes(12 * 60)
    }
    
    @IBAction func do24hButtonPressed(_ sender: Any) {
        snoozeMinutes(24 * 60)
    }
    
    fileprivate func snoozeMinutes(_ minutes : Int) {
        
        AlarmRule.snooze(minutes)
        
        AlarmSound.stop()
        AlarmSound.unmuteVolume()
        
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func dismiss(_ sender: Any) {
        AlarmSound.unmuteVolume()
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func doButtonPressed(_ sender: Any) {
        
        AlarmSound.unmuteVolume()
        AlarmRule.disableSnooze()
        
        self.dismiss(animated: true, completion: nil)
        //self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
