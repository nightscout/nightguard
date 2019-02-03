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
    
    static let dispatchOnce: Void = {
        customizeRows()
    }()
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        CustomFormViewController.dispatchOnce
        
        tableView.backgroundColor = UIColor.App.Preferences.background
        tableView.separatorColor = UIColor.App.Preferences.separator
        
        constructForm()
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
}

/// Eureka form rows customization
extension CustomFormViewController {
    
    static func customizeRows() {
        
        LabelRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.textLabel?.textColor = UIColor.App.Preferences.text
            cell.detailTextLabel?.textColor = UIColor.App.Preferences.detailText
        }
        
        TextRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.titleLabel?.textColor = UIColor.App.Preferences.text
            cell.textField?.textColor = UIColor.App.Preferences.text
            cell.textField?.setValue(UIColor.App.Preferences.placeholderText, forKeyPath: "_placeholderLabel.textColor")
            cell.textField?.setValue(UIFont.italicSystemFont(ofSize: 12), forKeyPath:"_placeholderLabel.font")
        }
        
        URLRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.titleLabel?.textColor = UIColor.App.Preferences.text
            cell.textField?.textColor = UIColor.App.Preferences.text
            cell.textField?.setValue(UIColor.App.Preferences.placeholderText, forKeyPath: "_placeholderLabel.textColor")
            cell.textField?.setValue(UIFont.italicSystemFont(ofSize: 12), forKeyPath:"_placeholderLabel.font")
        }
        
        SwitchRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.textLabel?.textColor = UIColor.App.Preferences.text
        }
        
        SliderRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.titleLabel?.textColor = UIColor.App.Preferences.text
            cell.valueLabel?.textColor = UIColor.App.Preferences.detailText
        }
        
        DateRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.textLabel?.textColor = UIColor.App.Preferences.text
            cell.detailTextLabel?.textColor = UIColor.App.Preferences.detailText
        }
    }
}
