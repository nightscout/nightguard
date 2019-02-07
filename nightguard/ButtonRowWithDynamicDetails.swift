//
//  ButtonRowWithDynamicDetails.swift
//  nightguard
//
//  Created by Florian Preknya on 2/7/19.
//  Copyright © 2019 private. All rights reserved.
//

import UIKit
import Eureka

final class ButtonRowWithDynamicDetails: _ButtonRowOf<String>, RowType {
    
    // the presented controller provider closure
    var controllerProvider: (() -> CustomFormViewController)?
    
    // subtitle text
    var detailTextProvider: (() -> String?)?
    
    required public init(tag: String?) {
        super.init(tag: tag)
        title = tag
        cellStyle = .subtitle
    }
    
    override func customDidSelect() {
        super.customDidSelect()
        guard !isDisabled else { return }
        
        guard let controllerProvider = self.controllerProvider else { return }
        
        let vc = controllerProvider()
        vc.title = title
        cell.formViewController()?.navigationController?.pushViewController(vc, animated: true)
    }
    
    override func customUpdateCell() {
        super.customUpdateCell()
        
        // always left!
        cell.textLabel?.textAlignment = .left
        cell.accessoryType = isDisabled ? .none : .disclosureIndicator
        
        // detail text can span on more than one line
        guard let detailTextProvider = self.detailTextProvider else { return }
        cell.detailTextLabel?.text = detailTextProvider()
        cell.detailTextLabel?.numberOfLines = 0
    }
}
