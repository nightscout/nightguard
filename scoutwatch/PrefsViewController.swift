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
    
    override func viewDidLoad() {
        super.viewDidLoad()

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

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func doEditingChangedAction(sender: AnyObject) {
        
        let defaults = NSUserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(hostUriTextField.text, forKey: "hostUri")
        
        sendToWatch(hostUriTextField.text!)
    }
    
    private func sendToWatch(hostUri : String) {
        do {
            let applicationDict = ["hostUri": hostUri]
            try WCSession.defaultSession().updateApplicationContext(applicationDict)
        } catch {
            print(error)
        }
    }
    
    // Remove keyboard by touching outside
    
    func onTouchGesture(){
        self.view.endEditing(true)
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
}

