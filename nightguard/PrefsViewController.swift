//
//  ViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import UIKit
import WatchConnectivity

class PrefsViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate {
    
    let displayTimespans = ["3 Hours", "6 Hours", "Last Night", "Last Day"]
    
    @IBOutlet weak var hostUriTextField: UITextField!
    
    @IBOutlet weak var versionLabel: UILabel!
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        displayTheApplicationVersionNumber()
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        let hostUri = defaults?.string(forKey: "hostUri")
        hostUriTextField.text = hostUri
        
        hostUriTextField.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(PrefsViewController.onTouchGesture))
        self.view.addGestureRecognizer(tap)
    }

    override func viewDidAppear(_ animated: Bool) {
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    func displayTheApplicationVersionNumber() {
        
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        versionLabel.text = "V\(versionNumber).\(buildNumber)"
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func doEditingChangedAction(_ sender: AnyObject) {
        
        hostUriTextField.text = addProtocolPartIfMissing(hostUriTextField.text!)
        UserDefaultsRepository.saveBaseUri(hostUriTextField.text!)
        sendValuesToAppleWatch()
    }
    
    // adds 'https://' if a '/' but no 'http'-part is found in the uri.
    func addProtocolPartIfMissing(_ uri : String) -> String {
        
        if (uri.contains("/") || uri.contains(".") || uri.contains(":"))
            && !uri.contains("http") {
            
            return "https://" + uri
        }
        
        return uri
    }
    
    // Close the soft keyboard if return has been selected
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        UserDefaultsRepository.saveBaseUri(hostUriTextField.text!)
        sendValuesToAppleWatch()
        retrieveAndStoreNightscoutUnits()
        
        textField.resignFirstResponder()
        return true
    }

    
    // Send the configuration values to the apple watch.
    // This has to be done here, because the watch has no access to the default values.
    // So this way we assure that the default values are submitted at least once after the
    // iOS App started the first time.
    //
    // This is enough, because the user has to start the ios app at least once before starting the
    // watch app: He has to enter the URI to the nightscout backend in the iOS app!
    func sendValuesToAppleWatch() {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        let alertIfAboveValue : Float = (defaults?.float(forKey: "alertIfAboveValue"))!
        let alertIfBelowValue : Float = (defaults?.float(forKey: "alertIfBelowValue"))!
        let hostUri : String = UserDefaultsRepository.readBaseUri()
        let units : Units = UserDefaultsRepository.readUnits()
        
        WatchService.singleton.sendToWatch(hostUri, alertIfBelowValue: alertIfBelowValue, alertIfAboveValue: alertIfAboveValue, units: units)
    }
    
    // Remove keyboard by touching outside
    
    func onTouchGesture(){
        self.view.endEditing(true)
        retrieveAndStoreNightscoutUnits()
    }
    
    // Picker-View methods
    
    func numberOfComponentsInPickerView(_ pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return displayTimespans.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return displayTimespans[row]
    }
    
    func retrieveAndStoreNightscoutUnits() {
        NightscoutService.singleton.readStatus { (units) in
            UserDefaultsRepository.saveUnits(units)
            self.sendValuesToAppleWatch()
        }
    }
}

