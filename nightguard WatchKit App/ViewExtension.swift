//
//  ViewExtension.swift
//  nightguard
//
//  Created by Dirk Hermanns on 08.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    func calculateAgeInMinutes(from timestamp: NSNumber) -> String {
        let timestampAsDate = Date(timeIntervalSince1970: timestamp.doubleValue / 1000)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: timestampAsDate, to: Date())
        if let ageInMinutes = components.minute {
            return "\(ageInMinutes)"
        }
        return "?"
    }
    
    func calculateAgeInMinutes(fromDouble timestamp: Double) -> String {
        let timestampAsDate = Date(timeIntervalSince1970: timestamp / 1000)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: timestampAsDate, to: Date())
        if let ageInMinutes = components.minute {
            return "\(ageInMinutes)"
        }
        return "?"
    }
}
