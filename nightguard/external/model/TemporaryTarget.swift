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
        if units.contains("mol") {
            // Looks like targetTop is stored as mmol => convert to mgdl
            temporaryTarget.targetTop =
                Int(UnitsConverter.mmolToMgdl(temporaryTargetDict["targetTop"] as? Float ?? 5.0))
        } else {
            temporaryTarget.targetTop = temporaryTargetDict["targetTop"] as? Int ?? 100
        }
        
        if units.contains("mol") {
            // looks like targetBottom is stored as mmol => convert to mgdl
            temporaryTarget.targetBottom =
                Int(UnitsConverter.mmolToMgdl(temporaryTargetDict["targetBottom"] as? Float ?? 5.0))
        } else {
            temporaryTarget.targetBottom = temporaryTargetDict["targetBottom"] as? Int ?? 100
        }
        
        temporaryTarget.createdAt = temporaryTargetDict["created_at"] as? String
        temporaryTarget.duration = temporaryTargetDict["duration"] as? Int
        
        return temporaryTarget
    }
}
