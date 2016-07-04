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
    
    override func viewWillAppear(animated: Bool) {
        
        let daysToBeDisplayed = UserDefaultsRepository.readDaysToBeDisplayed()
        
        day1IsActivatedSwitch.on = daysToBeDisplayed[0]
        day2IsActivatedSwitch.on = daysToBeDisplayed[1]
        day3IsActivatedSwitch.on = daysToBeDisplayed[2]
        day4IsActivatedSwitch.on = daysToBeDisplayed[3]
        day5IsActivatedSwitch.on = daysToBeDisplayed[4]
    }
    
    @IBAction func returnToMainView(sender: AnyObject) {
        
        UserDefaultsRepository.saveDaysToBeDisplayed(
            [day1IsActivatedSwitch.on,
                day2IsActivatedSwitch.on,
                day3IsActivatedSwitch.on,
                day4IsActivatedSwitch.on,
                day5IsActivatedSwitch.on])
        
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        
        return UIStatusBarStyle.LightContent
    }
}