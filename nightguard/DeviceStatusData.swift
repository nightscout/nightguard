//
//  DeviceStatusData.swift
//  nightguard
//
//  Created by Dirk Hermanns on 23.07.20.
//  Copyright © 2020 private. All rights reserved.
//

import Foundation

// Containing Data of the extended DeviceStatus of the pump.
// This is the active profile and informations about the temp basal rate.
class DeviceStatusData: NSObject, NSCoding, Codable {
    
    var activePumpProfile: String = "---"
    var pumpProfileActiveUntil: Date = Date()
    
    var temporaryBasalRate: String = ""
    var temporaryBasalRateActiveUntil: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case activePumpProfile
        case pumpProfileActiveUntil
        case temporaryBasalRate
        case temporaryBasalRateActiveUntil
    }
    
    override init() { super.init() }
    
    init(activePumpProfile: String, pumpProfileActiveUntil: Date?, temporaryBasalRate: String, temporaryBasalRateActiveUntil: Date) {
        
        self.activePumpProfile = activePumpProfile
        self.temporaryBasalRate = temporaryBasalRate
        self.temporaryBasalRateActiveUntil = temporaryBasalRateActiveUntil
        self.pumpProfileActiveUntil = pumpProfileActiveUntil ?? Date()
    }

    // MARK:- NSCoding interface implementation
    
    /*
        Code to deserialize BgData content. The error handling is needed in case that old serialized
        data leads to an error.
    */
    required init(coder decoder: NSCoder) {

        guard let activePumpProfile = decoder.decodeObject(forKey: "activePumpProfile") as? String else {
            return
        }
        self.activePumpProfile = activePumpProfile
        
        guard let pumpProfileActiveUntil = decoder.decodeObject(forKey: "pumpProfileActiveUntil") as? Date else {
            return
        }
        self.pumpProfileActiveUntil = pumpProfileActiveUntil
        
        guard let temporaryBasalRate = decoder.decodeObject(forKey: "temporaryBasalRate") as? String else {
            return
        }
        self.temporaryBasalRate = temporaryBasalRate
        
        guard let temporaryBasalRateActiveUntil = decoder.decodeObject(forKey: "temporaryBasalRateActiveUntil") as? Date else {
            return
        }
        self.temporaryBasalRateActiveUntil = temporaryBasalRateActiveUntil
    }
    
    /*
     Code to serialize the BgData to store them in UserDefaults.
     */
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.activePumpProfile, forKey: "activePumpProfile")
        aCoder.encode(self.pumpProfileActiveUntil, forKey: "pumpProfileActiveUntil")
        aCoder.encode(self.temporaryBasalRate, forKey: "temporaryBasalRate")
        aCoder.encode(self.temporaryBasalRateActiveUntil, forKey: "temporaryBasalRateActiveUntil")
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
        self.activePumpProfile = try container.decode(String.self, forKey: .activePumpProfile)
        self.pumpProfileActiveUntil = try container.decode(Date.self, forKey: .pumpProfileActiveUntil)
        self.temporaryBasalRate = try container.decode(String.self, forKey: .temporaryBasalRate)
        self.temporaryBasalRateActiveUntil = try container.decode(Date.self, forKey: .temporaryBasalRateActiveUntil)
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
        try container.encode(self.activePumpProfile, forKey: .activePumpProfile)
        try container.encode(self.pumpProfileActiveUntil, forKey: .pumpProfileActiveUntil)
        try container.encode(self.temporaryBasalRate, forKey: .temporaryBasalRate)
        try container.encode(self.temporaryBasalRateActiveUntil, forKey: .temporaryBasalRateActiveUntil)
    }
}
