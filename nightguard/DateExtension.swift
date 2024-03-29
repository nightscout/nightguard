//
//  DateExtension.swift
//  nightguard
//
//  Created by Dirk Hermanns on 18.07.20.
//  Copyright © 2020 private. All rights reserved.
//
import Foundation
import UIKit
import SwiftUI

extension Date {
    
    static func fromIsoString(isoTime: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        let isoTimeAsString = String(describing: isoTime)
        guard let convertedDate = dateFormatter.date(from: isoTimeAsString) else { return fromIsoStringWithMillis(isoTime : isoTime) }
        
        return convertedDate
    }
    
    static func fromIsoStringWithMillis(isoTime: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        let isoTimeAsString = String(describing: isoTime)
        guard let convertedDate = dateFormatter.date(from: isoTimeAsString) else {
            return Date()
        }
        
        return convertedDate
    }
    
    func toDateTimeString() -> String {

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        return dateFormatter.string(from: self)
    }
    
    func toLocalTimeString() -> String {

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        dateFormatter.pmSymbol = ""
        dateFormatter.amSymbol = ""
        
        return dateFormatter.string(from: self)
    }

    func toUTCMillis() -> String {
        
        return String(Int64((self.timeIntervalSince1970 * 1000.0).rounded()))
    }

    func convertToIsoDate() -> String {
        
        return ISO8601DateFormatter.string(
            from: self,
            timeZone: TimeZone.init(identifier: "UTC")!,
            formatOptions: [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
        )
    }
    
    func convertToIsoDateTime() -> String {
        let dateFormatter = ISO8601DateFormatter()
                        
        return dateFormatter.string(from: self)
    }
    
    func remainingMinutes() -> Int {
        
        return Calendar.current.dateComponents([.minute], from: Date(), to: self).minute ?? 0
    }
    
    // forms a new string like so
    // prefix + ageOf(isoTime)
    func convertToAge(prefix: String) -> String {
        
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.allowedUnits = [.day,.hour]
        dateComponentsFormatter.maximumUnitCount = 2
        dateComponentsFormatter.unitsStyle = .abbreviated
        
        guard let differenceString = dateComponentsFormatter.string(from: self, to: Date()) else {
            return prefix + "---"
        }
        
        return prefix + differenceString
    }
    
    func determineUIColorDependingOn(hoursUntilWarning: Int, hoursUntilCritical: Int) -> UIColor {
        
        let diffComponents = Calendar.current.dateComponents([.hour], from: self, to: Date())
        guard let hours = diffComponents.hour else {
            return UIColor.white
        }
        
        if hours > hoursUntilCritical {
            return UIColor.nightguardRed()
        }
        
        if hours > hoursUntilWarning {
            return UIColor.nightguardYellow()
        }
        
        return UIColor.white
    }
    
    func determineColorDependingOn(hoursUntilWarning: Int, hoursUntilCritical: Int) -> Color {
        
        return Color(determineUIColorDependingOn(hoursUntilWarning: hoursUntilWarning, hoursUntilCritical: hoursUntilCritical))
    }
}
