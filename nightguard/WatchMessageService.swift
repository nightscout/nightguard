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
    
    // This method gets called when the watch requests the baseUri from the Nightscout Backend
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        replyHandler(["baseUri": UserDefaultsRepository.readBaseUri()])
    }
    
    @available(iOS 9.3, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
}
