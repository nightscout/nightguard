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
    
    func toMillis() -> String {
        
        return String(Int64((self.timeIntervalSince1970 * 1000.0).rounded()))
    }

    func convertToIsoDate() -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone.init(secondsFromGMT: 0)
        
        return dateFormatter.string(from: self)
    }
    
    func convertToIsoDateTime() -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
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
    
    @available(watchOSApplicationExtension 6.0, *)
    @available(iOS 13.0, *)
    func determineColorDependingOn(hoursUntilWarning: Int, hoursUntilCritical: Int) -> Color {
        
        return Color(determineUIColorDependingOn(hoursUntilWarning: hoursUntilWarning, hoursUntilCritical: hoursUntilCritical))
    }
}
