//
//  ViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import UIKit
import WatchConnectivity

class PrefsViewController: UIViewController, WCSessionDelegate, UITextFieldDelegate, UIPickerViewDelegate {
    
    let displayTimespans = ["3 Hours", "6 Hours", "Last Night", "Last Day"]
    
    @IBOutlet weak var hostUriTextField: UITextField!
    
    @IBOutlet weak var versionLabel: UILabel!
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        displayTheApplicationVersionNumber()
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        let hostUri = defaults?.stringForKey("hostUri")
        hostUriTextField.text = hostUri
        
        // Init communication to apple watch
        if WCSession.isSupported() {
            
            let session = WCSession.defaultSession()
            session.delegate = self
            session.activateSession()
        }
        
        hostUriTextField.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(PrefsViewController.onTouchGesture))
        self.view.addGestureRecognizer(tap)
    }

    override func viewDidAppear(animated: Bool) {
        let value = UIInterfaceOrientation.Portrait.rawValue
        UIDevice.currentDevice().setValue(value, forKey: "orientation")
    }
    
    func displayTheApplicationVersionNumber() {
        
        let versionNumber: String = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        let buildNumber: String = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion") as! String

        versionLabel.text = "V\(versionNumber).\(buildNumber)"
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func doEditingChangedAction(sender: AnyObject) {
        
        hostUriTextField.text = addProtocolPartIfMissing(hostUriTextField.text!)
        UserDefaultsRepository.saveBaseUri(hostUriTextField.text!)
        sendValuesToAppleWatch()
    }
    
    // adds 'https://' if a '/' but no 'http'-part is found in the uri.
    func addProtocolPartIfMissing(uri : String) -> String {
        
        if (uri.containsString("/") || uri.containsString(".") || uri.containsString(":"))
            && !uri.containsString("http") {
            
            return "https://" + uri
        }
        
        return uri
    }
    
    // Close the soft keyboard if return has been selected
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        
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
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        
        let alertIfAboveValue : Float = (defaults?.floatForKey("alertIfAboveValue"))!
        let alertIfBelowValue : Float = (defaults?.floatForKey("alertIfBelowValue"))!
        let hostUri : String = (defaults?.stringForKey("hostUri"))!
        
        WatchService.singleton.sendToWatch(alertIfBelowValue, alertIfAboveValue: alertIfAboveValue)
        WatchService.singleton.sendToWatch(hostUri)
    }
    
    // Remove keyboard by touching outside
    
    func onTouchGesture(){
        self.view.endEditing(true)
        retrieveAndStoreNightscoutUnits()
    }
    
    // Picker-View methods
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return displayTimespans.count
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return displayTimespans[row]
    }
    
    func retrieveAndStoreNightscoutUnits() {
        NightscoutService.singleton.readStatus { (units) in
            UserDefaultsRepository.saveUnits(units)
            WatchService.singleton.sendToWatch(units)
        }
    }
}

