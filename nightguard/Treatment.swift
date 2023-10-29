//
//  Treatment.swift
//  nightguard
//
//  Created by Dirk Hermanns on 14.02.21.
//  Copyright © 2021 private. All rights reserved.
//

import Foundation

class Treatment: NSObject, NSSecureCoding, Codable {
    
    public var id : String
    public var timestamp : Double
    static var supportsSecureCoding: Bool {
        return true
    }
    
    public init(id : String, timestamp : Double) {
        self.id = id
        self.timestamp = timestamp
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
    }
    
    /*
        Code to deserialize Treatment content. The error handling is needed in case that old serialized
        data leads to an error.
    */
    required init(coder decoder: NSCoder) {

        self.id = ""
        self.timestamp = 0
        
        guard let id = decoder.decodeObject(forKey: "id") as? String else {
            return
        }
        
        let timestamp = decoder.decodeDouble(forKey: "timestamp")

        self.id = id
        self.timestamp = timestamp
    }
    
    /*
     Code to serialize the treatment to store them in UserDefaults.
     */
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.id, forKey: "id")
        aCoder.encode(self.timestamp, forKey: "timestamp")
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
        self.id = try container.decode(String.self, forKey: .id)
        self.timestamp = try container.decode(Double.self, forKey: .timestamp)
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
        try container.encode(self.id, forKey: .id)
        try container.encode(self.timestamp, forKey: .timestamp)
    }
}
