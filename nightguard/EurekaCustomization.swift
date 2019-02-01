//
//  EurekaCustomization.swift
//  nightguard
//
//  Created by Florian Preknya on 2/1/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

struct Eureka {
    
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
        
        DateRow.defaultCellUpdate = { cell, row in
            cell.backgroundColor = UIColor.App.Preferences.rowBackground
            cell.textLabel?.textColor = UIColor.App.Preferences.text
            cell.detailTextLabel?.textColor = UIColor.App.Preferences.detailText
        }
    }
}
