//
//  DateExtension.swift
//  nightguard
//
//  Created by Dirk Hermanns on 18.07.20.
//  Copyright © 2020 private. All rights reserved.
//
import Foundation

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
        guard let convertedDate = dateFormatter.date(from: isoTimeAsString) else { return Date() }
        
        return convertedDate
    }
    
    func convertToIsoDate() -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone.init(secondsFromGMT: 0)
        
        return dateFormatter.string(from: self)
    }
    
    func remainingMinutes() -> Int {
        
        return Calendar.current.dateComponents([.minute], from: Date(), to: self).minute ?? 0
    }
}
