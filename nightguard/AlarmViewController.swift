//
//  AlarmViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 03.05.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit
import WatchConnectivity

class AlarmViewController: UIViewController, WCSessionDelegate, UITextFieldDelegate {
    
    private let MAX_ALERT_ABOVE_VALUE : Float = 200
    private let MIN_ALERT_ABOVE_VALUE : Float = 80
    
    private let MAX_ALERT_BELOW_VALUE : Float = 150
    private let MIN_ALERT_BELOW_VALUE : Float = 50
    
    @IBOutlet weak var edgeDetectionSwitch: UISwitch!
    @IBOutlet weak var numberOfConsecutiveValues: UITextField!
    @IBOutlet weak var deltaAmount: UITextField!
    
    @IBOutlet weak var alertIfAboveValueLabel: UILabel!
    @IBOutlet weak var alertIfBelowValueLabel: UILabel!
    
    @IBOutlet weak var alertAboveSlider: UISlider!
    @IBOutlet weak var alertBelowSlider: UISlider!
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        edgeDetectionSwitch.on = (defaults?.boolForKey("edgeDetectionAlarmEnabled"))!
        numberOfConsecutiveValues.text = defaults?.stringForKey("numberOfConsecutiveValues")
        deltaAmount.text = defaults?.stringForKey("deltaAmount")
        
        alertIfAboveValueLabel.text = defaults?.stringForKey("alertIfAboveValue")
        alertAboveSlider.value = (Float(alertIfAboveValueLabel.text!)! - MIN_ALERT_ABOVE_VALUE) / MAX_ALERT_ABOVE_VALUE
        alertIfBelowValueLabel.text = defaults?.stringForKey("alertIfBelowValue")
        alertBelowSlider.value = (Float(alertIfBelowValueLabel.text!)! - MIN_ALERT_BELOW_VALUE) / MAX_ALERT_ABOVE_VALUE
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(AlarmViewController.onTouchGesture))
        self.view.addGestureRecognizer(tap)
    }
    
    @IBAction func edgeDetectionSwitchChanged(sender: AnyObject) {
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(edgeDetectionSwitch.on, forKey: "edgeDetectionAlarmEnabled")
        AlarmRule.isEdgeDetectionAlarmEnabled = edgeDetectionSwitch.on
    }
    
    @IBAction func valuesEditingChanged(sender: AnyObject) {
        guard let numberOfConsecutiveValues = Int(numberOfConsecutiveValues.text!)
        else {
            return
        }
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(numberOfConsecutiveValues, forKey: "numberOfConsecutiveValues")
        AlarmRule.numberOfConsecutiveValues = numberOfConsecutiveValues
    }
    
    @IBAction func deltaEditingChanged(sender: AnyObject) {
        guard let deltaAmount = Float(deltaAmount.text!)
        else {
            return
        }
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(deltaAmount, forKey: "deltaAmount")
        AlarmRule.deltaAmount = deltaAmount
    }
    
    @IBAction func aboveAlertValueChanged(sender: AnyObject) {
        let alertIfAboveValue = Float(MIN_ALERT_ABOVE_VALUE + alertAboveSlider.value * MAX_ALERT_ABOVE_VALUE)
        alertIfAboveValueLabel.text = String(format: "%.0f", alertIfAboveValue)
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(Int(alertIfAboveValueLabel.text!), forKey: "alertIfAboveValue")
        
        AlarmRule.alertIfAboveValue = alertIfAboveValue
        WatchService.singleton.sendToWatch(Float(alertIfBelowValueLabel.text!)!, alertIfAboveValue: alertIfAboveValue)
    }
    
    @IBAction func belowAlertValueChanged(sender: AnyObject) {
        let alertIfBelowValue = Float(MIN_ALERT_BELOW_VALUE + alertBelowSlider.value * MAX_ALERT_BELOW_VALUE)
        alertIfBelowValueLabel.text = String(format: "%.0f", alertIfBelowValue)
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(Int(alertIfBelowValue), forKey: "alertIfBelowValue")
        
        AlarmRule.alertIfBelowValue = alertIfBelowValue
        WatchService.singleton.sendToWatch(alertIfBelowValue, alertIfAboveValue: Float(alertIfAboveValueLabel.text!)!)
    }
    
    // Remove keyboard by touching outside
    
    func onTouchGesture(){
        self.view.endEditing(true)
    }
}