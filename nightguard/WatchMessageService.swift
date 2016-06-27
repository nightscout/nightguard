//
//  WCSessionDelegate.swift
//  nightguard
//
//  Created by Dirk Hermanns on 27.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import UIKit
import WatchConnectivity

// This class receieves Watch Request for the baseUri.
// The functionality is activated in the AppDelegate.
class WatchMessageService : NSObject, WCSessionDelegate {
    
    static let singleton = WatchMessageService()
    
    // This method gets called when the watch request the baseUri of the Nightscout Backend
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        replyHandler(["baseUri": UserDefaultsRepository.readBaseUri()])
    }
}