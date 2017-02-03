//
//  AlarmViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 03.05.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit
import WatchConnectivity

class AlarmViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var noDataAlarmOptions = ["15 Minutes", "20 Minutes", "25 Minutes", "30 Minutes", "35 Minutes", "40 Minutes", "45 Minutes"]
    
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
    
    @IBOutlet weak var unitsLabel: UILabel!
    
    @IBOutlet weak var noDataAlarmButton: UIButton!
    @IBOutlet weak var noDataAlarmPickerView: UIPickerView!
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Portrait
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        updateUnits()
        
        edgeDetectionSwitch.on = (defaults?.boolForKey("edgeDetectionAlarmEnabled"))!
        numberOfConsecutiveValues.text = defaults?.stringForKey("numberOfConsecutiveValues")
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(AlarmViewController.onTouchGesture))
        self.view.addGestureRecognizer(tap)
        
        noDataAlarmPickerView.delegate = self
        noDataAlarmPickerView.dataSource = self
    }
    
    override func viewWillAppear(animated: Bool) {
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        updateUnits()
        
        deltaAmount.text = UnitsConverter.toDisplayUnits((defaults?.stringForKey("deltaAmount"))!)
        
        alertIfAboveValueLabel.text = UnitsConverter.toDisplayUnits((defaults?.stringForKey("alertIfAboveValue"))!)
        alertAboveSlider.value = (UnitsConverter.toMgdl(alertIfAboveValueLabel.text!.floatValue) - MIN_ALERT_ABOVE_VALUE) / MAX_ALERT_ABOVE_VALUE
        alertIfBelowValueLabel.text = UnitsConverter.toDisplayUnits((defaults?.stringForKey("alertIfBelowValue"))!)
        alertBelowSlider.value = (UnitsConverter.toMgdl(alertIfBelowValueLabel.text!.floatValue) - MIN_ALERT_BELOW_VALUE) / MAX_ALERT_ABOVE_VALUE
        
        noDataAlarmButton.setTitle(defaults?.stringForKey("noDataAlarmAfterMinutes"), forState: UIControlState.Normal)
    }
    
    override func viewDidAppear(animated: Bool) {
        let value = UIInterfaceOrientation.Portrait.rawValue
        UIDevice.currentDevice().setValue(value, forKey: "orientation")
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
        let deltaAmountValue = UnitsConverter.toMgdl(deltaAmount.text!)
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(deltaAmountValue, forKey: "deltaAmount")
        AlarmRule.deltaAmount = deltaAmountValue
    }
    
    @IBAction func aboveAlertValueChanged(sender: AnyObject) {
        let alertIfAboveValue = getAboveAlarmValue()
        adjustLowerSliderValue()
        alertIfAboveValueLabel.text = UnitsConverter.toDisplayUnits(String(alertIfAboveValue))
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(alertIfAboveValue, forKey: "alertIfAboveValue")
        
        AlarmRule.alertIfAboveValue = alertIfAboveValue
        WatchService.singleton.sendToWatch(UnitsConverter.toMgdl(alertIfBelowValueLabel.text!), alertIfAboveValue: alertIfAboveValue)
    }
    
    @IBAction func belowAlertValueChanged(sender: AnyObject) {
        let alertIfBelowValue = getBelowAlarmValue()
        adjustAboveSliderValue()
        alertIfBelowValueLabel.text = UnitsConverter.toDisplayUnits(String(alertIfBelowValue))
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(alertIfBelowValue, forKey: "alertIfBelowValue")
        
        AlarmRule.alertIfBelowValue = alertIfBelowValue
        WatchService.singleton.sendToWatch(alertIfBelowValue, alertIfAboveValue: UnitsConverter.toMgdl(alertIfAboveValueLabel.text!))
    }
    
    func getAboveAlarmValue() -> Float {
        return Float(MIN_ALERT_ABOVE_VALUE + alertAboveSlider.value * MAX_ALERT_ABOVE_VALUE)
    }
    
    func getBelowAlarmValue() -> Float {
        return Float(MIN_ALERT_BELOW_VALUE + alertBelowSlider.value * MAX_ALERT_BELOW_VALUE)
    }
    
    func adjustLowerSliderValue() {
        if getAboveAlarmValue() - getBelowAlarmValue() < 1 {
            alertBelowSlider.setValue(
                (getAboveAlarmValue() - 1 - MIN_ALERT_BELOW_VALUE) / MAX_ALERT_BELOW_VALUE, animated: true)
            belowAlertValueChanged(alertBelowSlider)
        }
    }
    
    func adjustAboveSliderValue() {
        if getBelowAlarmValue() - getAboveAlarmValue() > 0 {
            alertAboveSlider.setValue(
                (getBelowAlarmValue() + 1 - MIN_ALERT_ABOVE_VALUE) / MAX_ALERT_ABOVE_VALUE, animated: true)
            aboveAlertValueChanged(alertAboveSlider)
        }
    }
    
    func updateUnits() {
        let units = UserDefaultsRepository.readUnits()
        
        if units == Units.mmol {
            unitsLabel.text = "mmol"
        } else {
            unitsLabel.text = "mg/dL"
        }
    }
    
    // Remove keyboard and PickerView by touching outside
    func onTouchGesture(){
        self.view.endEditing(true)
        self.noDataAlarmPickerView.hidden = true
    }
    
    
    // Methods for the noDataAlarmPickerView
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return noDataAlarmOptions[row]
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return noDataAlarmOptions.count
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    @IBAction func noDataAlarmButtonPressed(sender: AnyObject) {
        preselectItemInPickerView()
        noDataAlarmPickerView.hidden = false
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedMinutes = toButtonText(noDataAlarmOptions[row])
        noDataAlarmButton.setTitle(selectedMinutes, forState: UIControlState.Normal)
        
        // Remember the selected value by storing it as default setting
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(selectedMinutes, forKey: "noDataAlarmAfterMinutes")
        
        // Activate the new AlarmRule
        AlarmRule.minutesWithoutValues = Int(selectedMinutes)!
    }
    
    // Selects the right item that is shown in the noDataAlarmButton in the PickerView
    private func preselectItemInPickerView() {
        let rowOfSelectedItem : Int = noDataAlarmOptions.indexOf(noDataAlarmButton.currentTitle! + " Minutes")!
        noDataAlarmPickerView.selectRow(rowOfSelectedItem, inComponent: 0, animated: false)
    }
    
    private func toButtonText(pickerText : String) -> String {
        return pickerText.stringByReplacingOccurrencesOfString(" Minutes", withString: "")
    }
}
