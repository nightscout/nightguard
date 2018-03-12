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
    @IBOutlet var cachedValuesLabel: WKInterfaceLabel!
    @IBOutlet var backgroundUpdatesLabel: WKInterfaceLabel!
    
    @IBAction func doCloseAction() {
        self.dismiss()
    }
    
    override func willActivate() {
        
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        displayLabels()
    }
    
    func displayLabels() {
        
        serverUriLabel.setText(UserDefaultsRepository.readBaseUri())
        
        // version number
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionLabel.setText("V\(versionNumber).\(buildNumber)")
        
        // cached values
        let todaysBgData = NightscoutDataRepository.singleton.loadTodaysBgData()
        let yesterdaysBgData = NightscoutDataRepository.singleton.loadYesterdaysBgData()
        cachedValuesLabel.setText("\(todaysBgData.count) / \(yesterdaysBgData.count)")
        
        // background updates
        if #available(watchOSApplicationExtension 3.0, *) {
            if let ext = WKExtension.shared().rootInterfaceController as? InterfaceController {
                
                var text = "Complication updates (initiated from phone app): \(ext.phoneUpdates)"
                text += "\nNew data: \(ext.phoneUpdatesWithNewData), existing: \(ext.phoneUpdatesWithSameData), old: \(ext.phoneUpdatesWithOldData)\n"
                
                text += "\nBackground refreshes (background URL session started): \(ext.backgroundURLSessions)"
                text += "\nNew data: \(ext.backgroundURLSessionUpdatesWithNewData), existing: \(ext.backgroundURLSessionUpdatesWithSameData), old: \(ext.backgroundURLSessionUpdatesWithOldData)\n"
                
                //            if !ext.ndRequestErrorMessages.isEmpty {
                //                text += "Request errors: \n" + ext.ndRequestErrorMessages.joined(separator: "\n")
                //            }
                
                backgroundUpdatesLabel.setText(text)
            }
        } else {
            // Fallback on earlier versions
            backgroundUpdatesLabel.setText("NO")
        }
    }
}
