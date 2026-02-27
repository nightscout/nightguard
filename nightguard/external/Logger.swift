//
//  Logger.swift
//  nightguard
//
//  Created by JamOrHam on 27/02/2026.
//

import Foundation
import os

// Debug logger which records the timestamp, source file and line number in the output

enum Logger {

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private static let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "unknown.bundle", category: "bg")
    

    static func log(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {

        let timestamp = formatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent

        logger.debug("[\(timestamp)] [\(fileName):\(line)] \(function) → \(message)")
    }
}
