//
//  TemporaryTarget.swift
//  nightguard
//
//  Created by Dirk Hermanns on 17.03.21.
//  Copyright © 2021 private. All rights reserved.
//

import Foundation

class TemporaryTarget {
    
    public var targetTop : Int
    public var targetBottom : Int
    public var createdAt : String?
    public var duration : Int?
    
    public init() {
        self.targetTop = 100
        self.targetBottom = 100
    }
    
    public static func parse(temporaryTargetDict : [String:Any]) -> TemporaryTarget {
        
        let temporaryTarget = TemporaryTarget.init()
        
        let units = temporaryTargetDict["units"] as? String ?? "mgdl"
        let targetTop = (temporaryTargetDict["targetTop"] as? NSNumber)?.doubleValue
        let targetBottom = (temporaryTargetDict["targetBottom"] as? NSNumber)?.doubleValue
        if units.contains("mol") {
            // Looks like targetTop is stored as mmol => convert to mgdl
            temporaryTarget.targetTop =
                Int(UnitsConverter.mmolToMgdl(Float(targetTop ?? 5.0)))
        } else {
            temporaryTarget.targetTop = Int(targetTop ?? 100)
        }
        
        if units.contains("mol") {
            // looks like targetBottom is stored as mmol => convert to mgdl
            temporaryTarget.targetBottom =
                Int(UnitsConverter.mmolToMgdl(Float(targetBottom ?? 5.0)))
        } else {
            temporaryTarget.targetBottom = Int(targetBottom ?? 100)
        }
        
        temporaryTarget.createdAt = temporaryTargetDict["created_at"] as? String
        if temporaryTarget.createdAt == nil,
           let timestamp = (temporaryTargetDict["date"] as? NSNumber)?.doubleValue {
            temporaryTarget.createdAt = Date(timeIntervalSince1970: timestamp / 1000).convertToIsoDateTime()
        }
        temporaryTarget.duration = (temporaryTargetDict["duration"] as? NSNumber)?.intValue
        
        return temporaryTarget
    }
}
