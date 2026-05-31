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

    struct LogEntry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let message: String
        let level: LogLevel
        let category: LogCategory

        init(
            id: UUID = UUID(),
            timestamp: Date,
            message: String,
            level: LogLevel,
            category: LogCategory
        ) {
            self.id = id
            self.timestamp = timestamp
            self.message = message
            self.level = level
            self.category = category
        }

        enum LogLevel: String, CaseIterable, Codable {
            case debug = "DEBUG"
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"
        }

        enum LogCategory: String, CaseIterable, Codable {
            case all = "All"
            case backgroundUpdates = "Background Updates"
        }
    }

    @Published var logs: [LogEntry] = []

    private let maxLogs = 500
    private let queue = DispatchQueue(label: "com.nightguard.logger", qos: .utility)
    private let appGroupId = "group.de.my-wan.dhe.nightguard"
    private let persistedLogsKey = "AppLogger.persistedLogs"

    private init() {
        logs = loadPersistedLogs()
    }

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
                self.persistLogs(self.logs)
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
            self.sharedDefaults?.removeObject(forKey: self.persistedLogsKey)
        }
    }

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    private func loadPersistedLogs() -> [LogEntry] {
        guard let data = sharedDefaults?.data(forKey: persistedLogsKey),
              let logs = try? JSONDecoder().decode([LogEntry].self, from: data) else {
            return []
        }

        return Array(logs.suffix(maxLogs))
    }

    private func persistLogs(_ logs: [LogEntry]) {
        let logsToPersist = Array(logs.suffix(maxLogs))
        guard let data = try? JSONEncoder().encode(logsToPersist) else {
            return
        }

        sharedDefaults?.set(data, forKey: persistedLogsKey)
    }
}
