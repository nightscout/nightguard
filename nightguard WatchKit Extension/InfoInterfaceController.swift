//
//  InfoInterfaceController.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 30.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation
import WatchKit

@available(watchOSApplicationExtension 6.0, *)
class InfoInterfaceController: WKInterfaceController {
    
    @IBOutlet var versionLabel: WKInterfaceLabel!
    @IBOutlet var serverUriTextField: WKInterfaceTextField!
    @IBOutlet var cachedValuesLabel: WKInterfaceLabel!
    @IBOutlet var backgroundUpdatesLabel: WKInterfaceLabel!
    
    override public init() {
        super.init()
    }
    
    override func willActivate() {
        
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        displayLabels()
    }
    
    @IBAction func baseUriChanged(_ value: NSString?) {
        
        guard let baseUri = value else {
            return
        }
        UserDefaultsRepository.baseUri.value = baseUri as String
    }
    
    func displayLabels() {
        
        serverUriTextField.setText(UserDefaultsRepository.baseUri.value)
        serverUriTextField.sizeToFitWidth()
        
        // version number
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionLabel.setText("V\(versionNumber).\(buildNumber)")
        
        // cached values
        let todaysBgData = NightscoutDataRepository.singleton.loadTodaysBgData()
        let yesterdaysBgData = NightscoutDataRepository.singleton.loadYesterdaysBgData()
        cachedValuesLabel.setText("\(todaysBgData.count) / \(yesterdaysBgData.count)")
        
        // background updates
        var text = "📱Updates initiated by phone app: \(BackgroundRefreshLogger.phoneUpdates)"
        text += "\nNew data: \(BackgroundRefreshLogger.phoneUpdatesWithNewData), existing: \(BackgroundRefreshLogger.phoneUpdatesWithSameData), old: \(BackgroundRefreshLogger.phoneUpdatesWithOldData)\n"
        
        text += "\n⌚Background updates: \(BackgroundRefreshLogger.backgroundRefreshes) (\(BackgroundRefreshLogger.formattedBackgroundRefreshesPerHour) per hour)"
        text += "\nBackground URL sessions: \(BackgroundRefreshLogger.backgroundURLSessions) (\(BackgroundRefreshLogger.formattedBackgroundRefreshesStartingURLSessions))"
        
        text += "\nNew data: \(BackgroundRefreshLogger.backgroundURLSessionUpdatesWithNewData), existing: \(BackgroundRefreshLogger.backgroundURLSessionUpdatesWithSameData), old: \(BackgroundRefreshLogger.backgroundURLSessionUpdatesWithOldData)\n"
        
        if !BackgroundRefreshLogger.receivedData.isEmpty {
            text += "\nReceived data:\n"
            text += BackgroundRefreshLogger.receivedData.joined(separator: "\n")
            text += "\n"
        }
        
        if !BackgroundRefreshLogger.logs.isEmpty {
            text += "\nLogs from background tasks:\n"
            text += BackgroundRefreshLogger.logs.joined(separator: "\n")
        }
        
        backgroundUpdatesLabel.setText(text)
    }
}
