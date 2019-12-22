//
//  CustomFormViewController.swift
//  nightguard
//
//  Created by Florian Preknya on 2/1/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

class CustomFormViewController: FormViewController {
    
    private static let dispatchOnce: Void = {
        customizeRows()
    }()
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    var reconstructFormOnViewWillAppear: Bool {
        return false
    }
    
    fileprivate var firstAppearance = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        CustomFormViewController.dispatchOnce
        
        tableView.backgroundColor = UIColor.App.Preferences.background
        tableView.separatorColor = UIColor.App.Preferences.separator
        
        constructForm()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // only if the orientation is portrat we should consider reconstructing the form on view appear (otherwise it will crash!)
        if UIDevice.current.orientation == .portrait {
            reconstructFormIfNeeded()
        }
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // if did't have the chance to reconstruct the form on will appear because of the orientation, do it now!
        if UIDevice.current.orientation != .portrait {
            reconstructFormIfNeeded()
        }
        
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.backgroundView?.backgroundColor = UIColor.App.Preferences.background
            header.textLabel?.textColor = UIColor.App.Preferences.headerText
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let footer = view as? UITableViewHeaderFooterView {
            footer.textLabel?.textColor = UIColor.App.Preferences.footerText
        }
    }
    
    // to be implemented in subclasses
    func constructForm() {
    }
    
    private func reconstructFormIfNeeded() {
        
        if !firstAppearance {
            if reconstructFormOnViewWillAppear {
                
                // reconstruct the form if units were changed from last appearance
                UIView.performWithoutAnimation {
                    let scrollOffset = tableView.contentOffset
                    defer { tableView.contentOffset = scrollOffset }
                    form.removeAll()
                    constructForm()
                }
            }
        }
        
        firstAppearance = false
    }
}

/// Eureka form rows customization
extension CustomFormViewController {
    
    /// customization for all the rows used in the app
    static func customizeRows() {
        
        LabelRow.defaultCellUpdate = { cell, row in
            cell.customize()
        }
        
        TextRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.titleLabel?.textColor = UIColor.App.Preferences.text
            cell.textField?.textColor = UIColor.App.Preferences.text
//            cell.textField?.setValue(UIColor.App.Preferences.placeholderText, forKeyPath: "_placeholderLabel.textColor")
//            cell.textField?.setValue(UIFont.italicSystemFont(ofSize: 12), forKeyPath:"_placeholderLabel.font")
        }
        
        URLRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.titleLabel?.textColor = UIColor.App.Preferences.text
            cell.textField?.textColor = UIColor.App.Preferences.text
//            cell.textField?.setValue(UIColor.App.Preferences.placeholderText, forKeyPath: "_placeholderLabel.textColor")
//            cell.textField?.setValue(UIFont.italicSystemFont(ofSize: 12), forKeyPath:"_placeholderLabel.font")
        }
        
        SwitchRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.textLabel?.textColor = UIColor.App.Preferences.text
        }
        
        SliderRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.titleLabel?.textColor = UIColor.App.Preferences.text
            cell.valueLabel?.textColor = UIColor.App.Preferences.detailText
            cell.tintColor = UIColor.App.Preferences.tint
        }
        
        PushRow<Int>.defaultCellUpdate = { cell, row in
            cell.customize(selectable: true)
        }
        
        ButtonRow.defaultCellUpdate = { cell, row in
            cell.customize(selectable: true)
        }
        
        ButtonRowWithDynamicDetails.defaultCellUpdate = { cell, row in
            cell.customize(selectable: true)
        }
        
        DateRow.defaultCellUpdate = { cell, row in
            cell.customize()
        }
        
        ListCheckRow<Int>.defaultCellUpdate = { cell, row in
            cell.customize(selectable: true)
        }
        
        StepperRow.defaultCellUpdate = { cell, row in
            cell.customize()
        }
        
        SegmentedRow<Int>.defaultCellUpdate = { cell, row in
            cell.customize()
        }
        
        PickerInlineRow<Int>.defaultCellUpdate = { cell, row in
            cell.customize(selectable: true)
        }
        
        PickerRow<Int>.defaultCellUpdate = { cell, row in
            cell.customize(selectable: true)
            cell.pickerTextAttributes = [
                .foregroundColor : UIColor.App.Preferences.text
            ]
        }
    }
}

extension BaseCell {
    
    func customize(selectable: Bool = false) {
        backgroundColor = UIColor.App.Preferences.rowBackground
        textLabel?.textColor = UIColor.App.Preferences.text
        detailTextLabel?.textColor = UIColor.App.Preferences.detailText
        
        tintColor = UIColor.App.Preferences.tint
        
        if selectable {
            let view = UIView()
            view.backgroundColor = UIColor.App.Preferences.selectedRowBackground
            selectedBackgroundView = view
        }
    }
}

/// customize the selector view controller
extension SelectorViewController {
    
    func customize(header: String? = nil, footer: String? = nil) {
        dismissOnSelection = false
        dismissOnChange = false
        enableDeselection = false

        let _ = view // TRICK to force loading the view
        tableView.backgroundColor = UIColor.App.Preferences.background
        tableView.separatorColor = UIColor.App.Preferences.separator
        
        var reload = false
        
        if let headerTitle = header {
            form.last?.header = HeaderFooterView(title: headerTitle)
            reload = true
        }
        
        if let footerTitle = footer {
            form.last?.footer = HeaderFooterView(title: footerTitle)
            reload = true
        }
        
        if reload {
            tableView?.reloadData()
        }
    }
}

extension SliderRow {
    
    class func glucoseLevelSlider(initialValue: Float, minimumValue: Float, maximumValue: Float, snapIncrementForMgDl: Float = 10.0) -> SliderRow {
        
        return SliderRow() { row in
            row.value = Float(UnitsConverter.toDisplayUnits("\(initialValue)"))!
            }.cellSetup { cell, row in
                
                let minimumValue = Float(UnitsConverter.toDisplayUnits("\(minimumValue)"))!
                let maximumValue = Float(UnitsConverter.toDisplayUnits("\(maximumValue)"))!
                let snapIncrement = (UserDefaultsRepository.units.value == .mgdl) ? snapIncrementForMgDl : 0.1
                
                let steps = (maximumValue - minimumValue) / snapIncrement
                row.steps = UInt(steps.rounded())
                cell.slider.minimumValue = minimumValue
                cell.slider.maximumValue = maximumValue
                row.displayValueFor = { value in
                    guard let value = value else { return "" }
                    let units = UserDefaultsRepository.units.value.description
                    return String("\(value.cleanValue) \(units)")
                }
                
                // fixed width for value label
                let widthConstraint = NSLayoutConstraint(item: cell.valueLabel!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 96)
                cell.valueLabel.addConstraints([widthConstraint])
        }
    }
}
