//
//  WKInterfaceLabel.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 29.07.20.
//  Copyright © 2020 private. All rights reserved.
//

import Foundation
import WatchKit

extension WKInterfaceLabel {
    
    // forms a new string like so
    // prefix + ageOf(isoTime)
    // The color will be white/yellow/red depending on hoursUntilWarning and hoursUntilCritical.
    func convertToAge(prefix: String, time: Date, hoursUntilWarning: Int, hoursUntilCritical: Int) {
        
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.allowedUnits = [.day,.hour]
        dateComponentsFormatter.maximumUnitCount = 2
        dateComponentsFormatter.unitsStyle = .abbreviated
        
        guard let differenceString = dateComponentsFormatter.string(from: time, to: Date()) else {
            self.setText(prefix + "---")
            return
        }
        
        self.setText(prefix + differenceString)
        self.setTextColor(determineColorDependingOn(time: time, hoursUntilWarning: hoursUntilWarning, hoursUntilCritical: hoursUntilCritical))
    }
    
    fileprivate func determineColorDependingOn(time: Date, hoursUntilWarning: Int, hoursUntilCritical: Int) -> UIColor {
        
        let diffComponents = Calendar.current.dateComponents([.hour], from: time, to: Date())
        guard let hours = diffComponents.hour else {
            return UIColor.white
        }
        
        if hours > hoursUntilCritical {
            return UIColor.red
        }
        
        if hours > hoursUntilWarning {
            return UIColor.yellow
        }
        
        return UIColor.white
    }
}
