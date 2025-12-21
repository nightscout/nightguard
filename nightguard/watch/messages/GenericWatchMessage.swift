//
//  GenericWatchMessage.swift
//  nightguard
//
//  Created by Florian Preknya on 2/23/19.
//  Copyright © 2019 private. All rights reserved.
//

import Foundation

/// A message that wraps any codable struct/class
class GenericWatchMessage<T: Codable>: WatchMessage {
    
    typealias ValueType = T
    let value: ValueType
    
    var dictionary: [String : Any] {
        
        let jsonEncoder = JSONEncoder()
        if let jsonData = try? jsonEncoder.encode(value) {
            return ["data": jsonData]
        } else {
            print("GenericWatchMessage - failed to encode message!")
            return [:]
        }
    }
    
    init(_ value: ValueType) {
        self.value = value
    }
    
    required init?(dictionary: [String : Any]) {
        guard let data = dictionary["data"] as? Data else {
            print("GenericWatchMessage - failed to decode message!")
            return nil
        }
        
        let jsonDecoder = JSONDecoder()
        guard let value = try? jsonDecoder.decode(ValueType.self, from: data) else {
            print("GenericWatchMessage - failed to decode message!")
            return nil
        }
        
        self.value = value
    }
}
