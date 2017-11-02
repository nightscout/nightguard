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
    
    @IBOutlet var versionLabel: WKInterfaceLabel!
    @IBOutlet var serverUriLabel: WKInterfaceLabel!
    
    @IBAction func doCloseAction() {
        self.dismiss()
    }
    
    override func willActivate() {
        
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        displayTheApplicationVersionNumber()
        serverUriLabel.setText(UserDefaultsRepository.readBaseUri())
    }
    
    func displayTheApplicationVersionNumber() {
        
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        versionLabel.setText("V\(versionNumber).\(buildNumber)")
    }
}
