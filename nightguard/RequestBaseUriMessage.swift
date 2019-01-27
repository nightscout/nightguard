//
//  RequestBaseUriMessage.swift
//  nightguard
//
//  Created by Florian Preknya on 1/25/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// The request Uri message (initiated by watch app)
class RequestBaseUriMessage: EmptyWatchMessage {}

/// The response Uri message (returned by phone app)
class ResponseBaseUriMessage: WatchMessage {
    
    let baseUri: String
    
    var dictionary: [String : Any] {
        return ["baseUri": baseUri]
    }
    
    init(baseUri: String) {
        self.baseUri = baseUri
    }
    
    required init?(dictionary: [String : Any]) {
        guard let baseUri = dictionary["baseUri"] as? String else {
            return nil
        }
        
        self.baseUri = baseUri
    }
}
