//
//  AppLogger.swift
//  nightguard
//
//  Centralized logging service for the iOS app
//

import Foundation
import Combine

class AppLogger: ObservableObject {
    static let singleton = AppLogger()

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let level: LogLevel
        let category: LogCategory

        enum LogLevel: String, CaseIterable {
            case debug = "DEBUG"
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"
        }

        enum LogCategory: String, CaseIterable {
            case all = "All"
            case backgroundUpdates = "Background Updates"
        }
    }

    @Published var logs: [LogEntry] = []

    private let maxLogs = 500
    private let queue = DispatchQueue(label: "com.nightguard.logger", qos: .utility)

    private init() {}

    func debug(_ message: String, category: LogEntry.LogCategory = .all) {
        log(message, level: .debug, category: category)
    }

    func info(_ message: String, category: LogEntry.LogCategory = .all) {
        log(message, level: .info, category: category)
    }

    func warning(_ message: String, category: LogEntry.LogCategory = .all) {
        log(message, level: .warning, category: category)
    }

    func error(_ message: String, category: LogEntry.LogCategory = .all) {
        log(message, level: .error, category: category)
    }

    private func log(_ message: String, level: AppLogger.LogEntry.LogLevel, category: AppLogger.LogEntry.LogCategory) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level, category: category)

        queue.async {
            DispatchQueue.main.async {
                self.logs.append(entry)
                if self.logs.count > self.maxLogs {
                    self.logs.removeFirst(self.logs.count - self.maxLogs)
                }
            }
        }

        // Also print to console
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("[\(formatter.string(from: entry.timestamp))] [\(level.rawValue)] [\(category.rawValue)] \(message)")
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}