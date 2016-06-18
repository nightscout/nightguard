//
//  InfoInterfaceController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 30.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation
import WatchKit

class InfoInterfaceController: WKInterfaceController {
    
    @IBOutlet var serverUriLabel: WKInterfaceLabel!
    
    @IBAction func doCloseAction() {
        self.dismissController()
    }
    
    override func willActivate() {
        
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        serverUriLabel.setText(UserDefaultsRepository.readBaseUri())
    }
}