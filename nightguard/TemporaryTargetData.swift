//
//  TemporaryTargetData.swift
//  nightguard
//
//  Created by Dirk Hermanns on 27.07.20.
//  Copyright © 2020 private. All rights reserved.
//

import Foundation

class TemporaryTargetData: NSObject, NSCoding, Codable {
    
    var targetTop : Int = 100
    var targetBottom : Int = 100
    var activeUntilDate : Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case targetTop
        case targetBottom
        case activeUntilDate
    }
    
    override init() { super.init() }
    
    init(targetTop : Int, targetBottom : Int, activeUntilDate : Date) {
        
        self.targetTop = targetTop
        self.targetBottom = targetBottom
        self.activeUntilDate = activeUntilDate
    }

    // MARK:- NSCoding interface implementation
    
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
    }
    
    /*
     Code to serialize the TemporaryTargetData to store them in UserDefaults.
     */
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.targetTop, forKey: "targetTop")
        aCoder.encode(self.targetBottom, forKey: "targetBottom")
        aCoder.encode(self.activeUntilDate, forKey: "activeUntilDate")
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
    }
}
