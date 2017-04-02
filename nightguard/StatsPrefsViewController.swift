//
//  StatsPrefsViewController.swift
//  nightguard
//
//  Created by Dirk Hermanns on 04.07.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit

class StatsPrefsViewController : UIViewController {
    
    @IBOutlet weak var day1IsActivatedSwitch: UISwitch!
    @IBOutlet weak var day2IsActivatedSwitch: UISwitch!
    @IBOutlet weak var day3IsActivatedSwitch: UISwitch!
    @IBOutlet weak var day4IsActivatedSwitch: UISwitch!
    @IBOutlet weak var day5IsActivatedSwitch: UISwitch!
    
    override func viewWillAppear(_ animated: Bool) {
        
        let daysToBeDisplayed = UserDefaultsRepository.readDaysToBeDisplayed()
        
        day1IsActivatedSwitch.isOn = daysToBeDisplayed[0]
        day2IsActivatedSwitch.isOn = daysToBeDisplayed[1]
        day3IsActivatedSwitch.isOn = daysToBeDisplayed[2]
        day4IsActivatedSwitch.isOn = daysToBeDisplayed[3]
        day5IsActivatedSwitch.isOn = daysToBeDisplayed[4]
    }
    
    @IBAction func returnToMainView(_ sender: AnyObject) {
        
        UserDefaultsRepository.saveDaysToBeDisplayed(
            [day1IsActivatedSwitch.isOn,
                day2IsActivatedSwitch.isOn,
                day3IsActivatedSwitch.isOn,
                day4IsActivatedSwitch.isOn,
                day5IsActivatedSwitch.isOn])
        
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        
        return UIStatusBarStyle.lightContent
    }
}
