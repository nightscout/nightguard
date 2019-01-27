//
//  WatchMessage.swift
//  nightguard
//
//  Created by Florian Preknya on 1/25/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation
import WatchConnectivity


/// An abstraction of an watch message
protocol WatchMessage {
    
    init?(dictionary: [String : Any])
    var dictionary: [String : Any] { get }
}

extension WatchMessage {
        
    func send(replyHandler: (([String : Any]) -> Void)? = nil) {
        WatchMessageService.singleton.send(message: self, replyHandler: replyHandler)
    }
    
    func send<T: WatchMessage>(responseHandler: @escaping (T) -> Void) {
        WatchMessageService.singleton.send(request: self, responseHandler: responseHandler)
    }
}
