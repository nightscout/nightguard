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
    @IBOutlet weak var hostUriErrorLabel: UILabel!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var showRawBGSwitch: UISwitch!
    @IBOutlet weak var showBGOnAppBadgeSwitch: UISwitch!
    
    lazy var uriPickerView: UIPickerView = {
        let pickerView = UIPickerView()
        pickerView.delegate = self
        return pickerView
    }()
    
//    fileprivate var uriBeforeEditingSession: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        displayTheApplicationVersionNumber()
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        let hostUri = defaults?.string(forKey: "hostUri")
        hostUriTextField.text = hostUri
        
        hostUriTextField.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(PrefsViewController.onTouchGesture))
        self.view.addGestureRecognizer(tap)
        
        showRawBGSwitch.isOn = UserDefaultsRepository.readShowRawBG()
        showBGOnAppBadgeSwitch.isOn = UserDefaultsRepository.readShowBGOnAppBadge()
        
        showBookmarksButtonOnKeyboardIfNeeded()
        
        // no URI error message on startup
        hostUriErrorLabel.isHidden = true
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
    
    // MARK: UITextFieldDelegate methods
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        // reset to keyboard input
        textField.inputView = nil
        
        // keep the URI before start editing
//        uriBeforeEditingSession = textField.text
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        
        guard reason == .committed else {
            return
        }
        
//        guard uriBeforeEditingSession != hostUriTextField.text else {
//            return
//        }
        
        let hostUri = hostUriTextField.text!
        UserDefaultsRepository.saveBaseUri(hostUri)
        sendValuesToAppleWatch()
        
        NightscoutCacheService.singleton.resetCache()
        NightscoutDataRepository.singleton.storeTodaysBgData([])
        NightscoutDataRepository.singleton.storeYesterdaysBgData([])
        NightscoutDataRepository.singleton.storeCurrentNightscoutData(NightscoutData())
        
        retrieveAndStoreNightscoutUnits { [unowned self] error in
            
            guard error == nil else {
                self.hostUriErrorLabel.text = "❌ \(error!.localizedDescription)"
                self.hostUriErrorLabel.isHidden = false
                return
            }
            
            // hide the error message
            self.hostUriErrorLabel.isHidden = true
         
            // add host URI only if status request was successful
            self.addUriEntryToPickerView(hostUri: hostUri)
        }
    }
    
    //     Close the soft keyboard if return has been selected
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @IBAction func textFieldDidChange(_ textField: UITextField) {
        textField.text = addProtocolPartIfMissing(textField.text!)
    }
    
    // adds 'https://' if a '/' but no 'http'-part is found in the uri.
    func addProtocolPartIfMissing(_ uri : String) -> String {
        
        if (uri.contains("/") || uri.contains(".") || uri.contains(":"))
            && !uri.contains("http") {
            
            return "https://" + uri
        }
        
        return uri
    }

    func addUriEntryToPickerView(hostUri : String) {
        
        if hostUri == "" {
            // ignore empty values => don't add them to the history of Uris
            return
        }
        
        var nightscoutUris = GuiStateRepository.singleton.loadNightscoutUris()
        if !nightscoutUris.contains(hostUri) {
            nightscoutUris.insert(hostUri, at: 0)
            nightscoutUris = limitAmountOfUrisToFive(nightscoutUris: nightscoutUris)
            GuiStateRepository.singleton.storeNightscoutUris(nightscoutUris: nightscoutUris)
            uriPickerView.reloadAllComponents()
            
            showBookmarksButtonOnKeyboardIfNeeded()
        }
    }
    
    func limitAmountOfUrisToFive(nightscoutUris : [String]) -> [String] {
        var uris = nightscoutUris
        while uris.count > 5 {
            uris.removeLast()
        }
        return uris
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
        let showRawBG : Bool = UserDefaultsRepository.readShowRawBG()
        
        WatchService.singleton.sendToWatch(hostUri, alertIfBelowValue: alertIfBelowValue, alertIfAboveValue: alertIfAboveValue, units: units, showRawBG: showRawBG)
    }
    
    // Remove keyboard by touching outside
    
    @objc func onTouchGesture(){
        self.view.endEditing(true)
    }
    
    // RawBG switch
    @IBAction func onShowRawBGValueChanged(_ sender: UISwitch) {
        UserDefaultsRepository.saveShowRawBG(sender.isOn)
        sendValuesToAppleWatch()
    }
    
    @IBAction func onShowBGOnAppBadgeChanged(_ sender: UISwitch) {
        
        if sender.isOn {
            UIApplication.shared.setCurrentBGValueOnAppBadge()
        } else {
            UIApplication.shared.clearAppBadge()
        }
        
        UserDefaultsRepository.saveShowBGOnAppBadge(sender.isOn)
    }
    
    // MARK: Picker-View methods
    
    @objc func numberOfComponentsInPickerView(_ pickerView: UIPickerView) -> Int {
        return 1
    }
    
    @objc func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return GuiStateRepository.singleton.loadNightscoutUris().count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return GuiStateRepository.singleton.loadNightscoutUris()[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        hostUriTextField.text = GuiStateRepository.singleton.loadNightscoutUris()[row]
        self.view.endEditing(true)
    }
    
    func retrieveAndStoreNightscoutUnits(completion: @escaping (Error?) -> Void) {
        NightscoutService.singleton.readStatus { [unowned self] (result: NightscoutRequestResult<Units>) in
            
            switch result {
            case .data(let units):
                UserDefaultsRepository.saveUnits(units)
                completion(nil)
                
            case .error(let error):
                completion(error)
            }
        }
    }
    
    fileprivate func showBookmarksButtonOnKeyboardIfNeeded() {
        
        guard GuiStateRepository.singleton.loadNightscoutUris().count > 1 else {
            return
        }
        
        let bookmarkToolbar = UIToolbar(frame:CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 30))
        bookmarkToolbar.barStyle = .blackTranslucent
        bookmarkToolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(toggleKeyboardAndBookmarks))
        ]
        bookmarkToolbar.sizeToFit()
        hostUriTextField.inputAccessoryView = bookmarkToolbar
    }
    
    @objc func toggleKeyboardAndBookmarks() {
        
        if hostUriTextField.inputView != nil {
           hostUriTextField.inputView = nil
        } else {
            hostUriTextField.inputView = uriPickerView
        }
        
        hostUriTextField.reloadInputViews()
    }

}

