//
//  DateExtension.swift
//  nightguard
//
//  Created by Dirk Hermanns on 18.07.20.
//  Copyright © 2020 private. All rights reserved.
//
import Foundation

extension Date {
    
    func convertToIsoDate() -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone.init(secondsFromGMT: 0)
        
        return dateFormatter.string(from: self)
    }
    
    static func convertToAge(isoTime : Any) -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        let isoTimeAsString = String(describing: isoTime)
        guard let oldDate = dateFormatter.date(from: isoTimeAsString) else { return convertToAgeWithMillis(isoTime : isoTime) }
        
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.allowedUnits = [.day,.hour]
        dateComponentsFormatter.maximumUnitCount = 2
        dateComponentsFormatter.unitsStyle = .abbreviated
        
        guard let differenceString = dateComponentsFormatter.string(from: oldDate, to: Date()) else { return "---" }
        return differenceString
    }
    
    static func convertToAgeWithMillis(isoTime : Any) -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        let isoTimeAsString = String(describing: isoTime)
        guard let oldDate = dateFormatter.date(from: isoTimeAsString) else { return "---" }
        
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.allowedUnits = [.day,.hour]
        dateComponentsFormatter.maximumUnitCount = 2
        dateComponentsFormatter.unitsStyle = .abbreviated
        
        guard let differenceString = dateComponentsFormatter.string(from: oldDate, to: Date()) else { return "---" }
        return differenceString
    }
}
