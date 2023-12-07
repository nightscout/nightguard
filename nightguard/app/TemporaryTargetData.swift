//
//  TemporaryTargetData.swift
//  nightguard
//
//  Created by Dirk Hermanns on 27.07.20.
//  Copyright © 2020 private. All rights reserved.
//

import Foundation

class TemporaryTargetData: NSObject, Codable, NSSecureCoding {
    
    var targetTop : Int = 100
    var targetBottom : Int = 100
    var activeUntilDate : Date = Date()
    var lastUpdate : Date?
    
    static var supportsSecureCoding: Bool {
        return true
    }
    
    enum CodingKeys: String, CodingKey {
        case targetTop
        case targetBottom
        case activeUntilDate
        case lastUpdate
    }
    
    override init() { super.init() }
    
    init(targetTop : Int, targetBottom : Int, activeUntilDate : Date) {
        
        self.targetTop = targetTop
        self.targetBottom = targetBottom
        self.activeUntilDate = activeUntilDate
    }

    // true if no refresh is need. This is the case, if the last update has been before 5 minutes or less.
    public func isUpToDate() -> Bool {
        
        guard let lastUpdate = lastUpdate else {
            return false
        }
        // Calculate the time interval between the current date and the provided date
        let timeInterval = Date().timeIntervalSince(lastUpdate)

        // Check if the time interval is less than 5 minutes (300 seconds)
        return timeInterval < 300
    }
    
    /*
        Code to deserialize BgData content. The error handling is needed in case that old serialized
        data leads to an error.
    */
    required init(coder decoder: NSCoder) {

        self.targetTop = decoder.decodeInteger(forKey: "targetTop")
        
        self.targetBottom = decoder.decodeInteger(forKey: "targetBottom")
        
        if let activeUntilDate = decoder.decodeObject(forKey: "activeUntilDate") as? Date {
            self.activeUntilDate = activeUntilDate
        }
        
        if let lastUpdate = decoder.decodeObject(forKey: "lastUpdate") as? Date {
            self.lastUpdate = lastUpdate
        }
    }
    
    /*
     Code to serialize the TemporaryTargetData to store them in UserDefaults.
     */
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.targetTop, forKey: "targetTop")
        aCoder.encode(self.targetBottom, forKey: "targetBottom")
        aCoder.encode(self.activeUntilDate, forKey: "activeUntilDate")
        aCoder.encode(self.lastUpdate, forKey: "lastUpdate")
    }
    
    
    // MARK:- Codable interface implementation
    
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.targetTop = try container.decode(Int.self, forKey: .targetTop)
        self.targetBottom = try container.decode(Int.self, forKey: .targetBottom)
        self.activeUntilDate = try container.decode(Date.self, forKey: .activeUntilDate)
        self.lastUpdate = try container.decode(Date.self, forKey: .lastUpdate)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// If the value fails to encode anything, `encoder` will encode an empty
    /// keyed container in its place.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.targetTop, forKey: .targetTop)
        try container.encode(self.targetBottom, forKey: .targetBottom)
        try container.encode(self.activeUntilDate, forKey: .activeUntilDate)
        try container.encode(self.lastUpdate, forKey: .lastUpdate)
    }
}
