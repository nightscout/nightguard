//
//  SnoozeAlarmViewController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 21.04.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import UIKit

class SnoozeAlarmViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // customize all buttons
        let buttons = self.view.subviews.filter { $0 is UIButton }
        buttons.forEach { button in
            button.layer.cornerRadius = 4
            button.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        }
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
    
    @IBAction func doButtonPressed(_ sender: Any) {
        
        AlarmSound.unmuteVolume()
        self.dismiss(animated: true, completion: nil)
        //self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
