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

        enum LogLevel: String, CaseIterable {
            case debug = "DEBUG"
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"
        }
    }

    @Published var logs: [LogEntry] = []

    private let maxLogs = 500
    private let queue = DispatchQueue(label: "com.nightguard.logger", qos: .utility)

    private init() {}

    func debug(_ message: String) {
        log(message, level: .debug)
    }

    func info(_ message: String) {
        log(message, level: .info)
    }

    func warning(_ message: String) {
        log(message, level: .warning)
    }

    func error(_ message: String) {
        log(message, level: .error)
    }

    private func log(_ message: String, level: AppLogger.LogEntry.LogLevel) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)

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
        print("[\(formatter.string(from: entry.timestamp))] [\(level.rawValue)] \(message)")
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}