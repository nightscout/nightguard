//
//  ViewController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 20.11.15.
//  Copyright © 2015 private. All rights reserved.
//

import UIKit
import Eureka

class PrefsViewController: CustomFormViewController {
    
    private var nightscoutURLRow: URLRow!
    private var nightscoutURLRule = RuleValidNightscoutURL()
    
    lazy var uriPickerView: UIPickerView = {
        let pickerView = UIPickerView()
        pickerView.delegate = self
        return pickerView
    }()
    
    var hostUriTextField: UITextField {
        return nightscoutURLRow.cell.textField
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        showBookmarksButtonOnKeyboardIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func constructForm() {
        
        nightscoutURLRow = URLRow() { row in
            row.title = NSLocalizedString("URL", comment: "Title for URL")
            row.placeholder = "http://night.fritz.box"
            row.placeholderColor = UIColor.gray
            row.value = URL(string: UserDefaultsRepository.baseUri.value)
            row.add(rule: nightscoutURLRule)
            row.validationOptions = .validatesOnDemand
            }.onChange { [weak self] row in
                guard let urlString = row.value?.absoluteString, !urlString.isEmpty else { return }
                if let updatedUrlString = self?.addProtocolPartIfMissing(urlString), let updatedUrl = URL(string: updatedUrlString) {
                    row.value = updatedUrl
                    row.updateCell()
                }
            }.onCellHighlightChanged { [weak self] (cell, row) in
                if row.isHighlighted == false {
                    
                    // editing finished
//                    guard row.validate().isEmpty else { return }
                    guard let value = row.value else { return }
                    self?.nightscoutURLChanged(value)
                }
            }
            .onRowValidationChanged { cell, row in
                let rowIndex = row.indexPath!.row
                while row.section!.count > rowIndex + 1 && row.section?[rowIndex  + 1] is LabelRow {
                    row.section?.remove(at: rowIndex + 1)
                }
                if !row.isValid {
                    for (index, validationMsg) in row.validationErrors.map({ $0.msg }).enumerated() {
                        let labelRow = LabelRow() {
                            let title = "❌ \(validationMsg)"
                            $0.title = title
                            $0.cellUpdate { cell, _ in
                                cell.textLabel?.textColor = UIColor.red
                            }
                            $0.cellSetup { cell, row in
                                cell.textLabel?.numberOfLines = 0
                            }
                            let rows = CGFloat(title.count / 50) + 1 // we condiser 80 characters are on a line
                            $0.cell.height = { 30 * rows }
                        }
                        let insertionRow = row.indexPath!.row + index + 1
                        row.section?.insert(labelRow, at: insertionRow)
                    }
                }
        }
        
        
        form +++ Section(header: "NIGHTSCOUT", footer: NSLocalizedString("Enter the URI to your Nightscout Server here. E.g. 'https://nightscout?token=mytoken'", comment: "Footer for URL"))
            <<< nightscoutURLRow
            
            +++ Section(footer: NSLocalizedString("Keeping the screen active is of paramount importance if using the app as a night guard. We suggest leaving it ALWAYS ON.", comment: "Footer for Dim Screen"))
            <<< SwitchRow("KeepScreenActive") { row in
                row.title = NSLocalizedString("Keep the Screen Active", comment: "Label for Keep the Screen Active")
                row.value = UserDefaultsRepository.screenlockSwitchState.value
                }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    
                    if value {
                        UserDefaultsRepository.screenlockSwitchState.value = value
                    } else {
                        self?.showYesNoAlert(
                            title: NSLocalizedString("ARE YOU SURE?", comment: "Title for confirmation"),
                            message: NSLocalizedString("Keep this switch ON to disable the screenlock and prevent the app to get stopped!", comment: "Message for confirmation"),
                            yesHandler: {
                                UserDefaultsRepository.screenlockSwitchState.value = value
                            },
                            noHandler: {
                                row.value = true
                                row.updateCell()
                        })
                    }
            }
            <<< PushRow<Int>() { row in
                row.title = NSLocalizedString("Dim Screen When Idle", comment: "Label for Dim screen when idle")
                row.hidden = "$KeepScreenActive == false"
                row.options = [0, 1, 2, 3, 4, 5, 10, 15]
                row.displayValueFor = { option in
                    switch option {
                    case 0: return NSLocalizedString("Never", comment: "Option")
                    case 1: return NSLocalizedString("1 Minute", comment: "Option")
                    default: return "\(option!) " + NSLocalizedString("Minutes", comment: "Option")
                    }
                }
                row.value = UserDefaultsRepository.dimScreenWhenIdle.value
                row.selectorTitle = NSLocalizedString("Dim Screen When Idle", comment: "Label for Dim screen when idle")
                }.onPresent { form, selector in
                    selector.customize(header: "", footer: NSLocalizedString("Reduce screen brightness after detecting user inactivity for more than selected time period.", comment: "Footer for Reduce screen brightness"))
                }.onChange { row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.dimScreenWhenIdle.value = value
                    row.reload()
            }
            
            +++ Section()
            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Show Statistics", comment: "Label for Show statistics")
                row.value = UserDefaultsRepository.showStats.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.showStats.value = value
            }

            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Show Raw BG and Noise Level", comment: "Label for Show Raw BG")
                row.value = UserDefaultsRepository.showRawBG.value
                }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    
                    if value {
                        self?.showAlert(title: NSLocalizedString("IMPORTANT", comment: "Title for confirmation"), message: NSLocalizedString("For receiving the raw BG and noise level values, the rawbg plugin should be enabled on your Nightscout Server. Please note that this works on Dexcom only!", comment: "Body of confirmation"))
                    }
                    
                    UserDefaultsRepository.showRawBG.value = value
            }

            <<< SwitchRow() { row in
                row.title = NSLocalizedString("Show BG on App Badge", comment: "Label for Show BG on Badge")
                row.value = UserDefaultsRepository.showBGOnAppBadge.value
                }.onChange { row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.showBGOnAppBadge.value = value
            }
            
            <<< LabelRow() { row in
                row.title = NSLocalizedString("Version", comment: "Label for Version")
                
                let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
                let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
                row.value = "V\(versionNumber).\(buildNumber)"
        }
    }
    
    private func nightscoutURLChanged(_ url: URL) {
        
        UserDefaultsRepository.baseUri.value = url.absoluteString
        
        NightscoutCacheService.singleton.resetCache()
        NightscoutDataRepository.singleton.storeTodaysBgData([])
        NightscoutDataRepository.singleton.storeYesterdaysBgData([])
        NightscoutDataRepository.singleton.storeCurrentNightscoutData(NightscoutData())
        
        retrieveAndStoreNightscoutUnits { [weak self] error in
            
            // keep the error message
            self?.nightscoutURLRule.nightscoutError = error
            
            self?.nightscoutURLRow.cleanValidationErrors()
            self?.nightscoutURLRow.validate()
            self?.nightscoutURLRow.updateCell()
            
            if error == nil {
                
                // add host URI only if status request was successful
                self?.addUriEntryToPickerView(hostUri: url.absoluteString)
            }
        }
    }
    
    // adds 'https://' if a '/' but no 'http'-part is found in the uri.
    private func addProtocolPartIfMissing(_ uri : String) -> String? {
        
        if (uri.contains("/") || uri.contains(".") || uri.contains(":"))
            && !uri.contains("http") {
            
            return "https://" + uri
        }
        
        return nil
    }
    
    private func retrieveAndStoreNightscoutUnits(completion: @escaping (Error?) -> Void) {
        NightscoutService.singleton.readStatus { (result: NightscoutRequestResult<Units>) in
            
            switch result {
            case .data(let units):
                UserDefaultsRepository.units.value = units
                completion(nil)
                
            case .error(let error):
                completion(error)
            }
        }
    }
    
    private func showBookmarksButtonOnKeyboardIfNeeded() {
        
        guard UserDefaultsRepository.nightscoutUris.value.count > 1 else {
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
        
        // select current URI
        if let index = UserDefaultsRepository.nightscoutUris.value.firstIndex(of: UserDefaultsRepository.baseUri.value) {
            uriPickerView.selectRow(index, inComponent: 0, animated: false)
        }
    }
    
    private func addUriEntryToPickerView(hostUri : String) {
        
        if hostUri == "" {
            // ignore empty values => don't add them to the history of Uris
            return
        }
        
        var nightscoutUris = UserDefaultsRepository.nightscoutUris.value
        if !nightscoutUris.contains(hostUri) {
            nightscoutUris.insert(hostUri, at: 0)
            nightscoutUris = limitAmountOfUrisToFive(nightscoutUris: nightscoutUris)
            UserDefaultsRepository.nightscoutUris.value = nightscoutUris
            uriPickerView.reloadAllComponents()
            
            showBookmarksButtonOnKeyboardIfNeeded()
        }
    }
    
    private func limitAmountOfUrisToFive(nightscoutUris : [String]) -> [String] {
        var uris = nightscoutUris
        while uris.count > 5 {
            uris.removeLast()
        }
        return uris
    }    
}

extension PrefsViewController: UIPickerViewDelegate {
    
    @objc func numberOfComponentsInPickerView(_ pickerView: UIPickerView) -> Int {
        return 1
    }
    
    @objc func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return UserDefaultsRepository.nightscoutUris.value.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return UserDefaultsRepository.nightscoutUris.value[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        let stringURL = UserDefaultsRepository.nightscoutUris.value[row]
        if let url = URL(string: stringURL) {
            nightscoutURLRow.value = url
            nightscoutURLRow.updateCell()
        }

        self.view.endEditing(true)
    }
}


// Nightscout URL validation rule
fileprivate class RuleValidNightscoutURL: RuleType {
    
    var id: String?
    var validationError: ValidationError
    
    var nightscoutError: Error? {
        didSet {
            validationError = ValidationError(msg: nightscoutError?.localizedDescription ?? "")
        }
    }
    
    //    private let ruleURL = RuleURL()
    
    init() {
        validationError = ValidationError(msg: "")
    }
    
    func isValid(value: URL?) -> ValidationError? {
        
        // NOTE: commented out RuleURL because it has a bug (regexp doesn't allow url port definition)
        //        if let urlError = ruleURL.isValid(value: value) {
        //            return urlError
        //        }
        
        if let _ = self.nightscoutError {
            return validationError
        } else {
            return nil
        }
    }
}

