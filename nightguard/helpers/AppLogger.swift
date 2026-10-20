//
//  AppLogger.swift
//  nightguard
//
//  Centralized logging service for the iOS app
//

import Foundation
import Combine
import os.log

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
            case nightscout = "Nightscout"
        }
    }

    @Published var logs: [LogEntry] = []

    #if os(watchOS)
    private let store = BoundedMemoryLog<LogEntry>(maxEntries: 100, maxBytes: 128 * 1024)
    #else
    private let store = BoundedLogFile<LogEntry>(name: "app", maxEntries: 500, maxBytes: 512 * 1024)
    #endif

    private init() {
        store.load { [weak self] entries in
            self?.logs = entries
        }
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
        let message = LogStorage.boundedMessage(message)
        let entry = LogEntry(timestamp: Date(), message: message, level: level, category: category)
        store.append(entry) { [weak self] entries in
            self?.logs = entries
        }

        #if !os(watchOS)
        // Also print to console on iOS.
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print("[\(formatter.string(from: entry.timestamp))] [\(level.rawValue)] [\(category.rawValue)] \(message)")
        #endif
    }

    func clearLogs() {
        store.clear { [weak self] entries in
            self?.logs = entries
        }
    }
}

/// Shared by all targets compiling AppLogger.swift. No diagnostic data is written to preferences.
enum LogStorage {
    private static let systemLog = OSLog(subsystem: "de.my-wan.dhe.nightguard", category: "LogStorage")

    private static let startupDiagnostics: Void = {
        guard let defaults = AppGroupPreferences.defaults else { return }
        DispatchQueue.global(qos: .utility).async {
            // Report sizes only: values may contain credentials or health data.
            let sizes = defaults.dictionaryRepresentation().compactMap { key, value -> (String, Int)? in
                guard let data = try? PropertyListSerialization.data(
                    fromPropertyList: [key: value], format: .binary, options: 0
                ) else { return nil }
                return (key, data.count)
            }.sorted { $0.1 > $1.1 }.prefix(5)
            for (key, size) in sizes {
                os_log("Preference size: key=%{public}@ bytes=%{public}d", log: systemLog, type: .info, key, size)
            }
        }
    }()

    static func prepareForStartup() {
        _ = AppGroupPreferences.defaults
        #if !os(watchOS)
        _ = startupDiagnostics
        #endif
    }

    static func removeLegacyLogs(from defaults: UserDefaults) {
        defaults.removeObject(forKey: "AppLogger.persistedLogs")
        defaults.removeObject(forKey: "BackgroundRefreshLogger.sharedLogs")
    }

    static func boundedMessage(_ message: String) -> String {
        let limit = 4 * 1024
        guard message.utf8.count > limit else { return message }
        let marker = " … [truncated]"
        var bytes = Array(message.utf8.prefix(limit - marker.utf8.count))
        while String(bytes: bytes, encoding: .utf8) == nil { bytes.removeLast() }
        return (String(bytes: bytes, encoding: .utf8) ?? "") + marker
    }

    static func fileURL(name: String) -> URL? {
        prepareForStartup()
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.APP_GROUP_ID
        ) else {
            reportFailure("App group unavailable; keeping logs in memory")
            return nil
        }
        return container.appendingPathComponent("Library/Caches/Logs", isDirectory: true)
            .appendingPathComponent("\(Bundle.main.bundleIdentifier ?? "nightguard")-\(name).json")
    }

    static func reportFailure(_ message: String) {
        os_log("%{public}@", log: systemLog, type: .error, message)
    }
}

/// Session-only storage for watch logs. Synchronous mutations avoid a backlog of
/// queued log messages; only the new entry is encoded to measure its byte cost.
final class BoundedMemoryLog<Entry: Codable> {
    private let lock = NSLock()
    private let maxEntries: Int
    private let maxBytes: Int
    private var entries: [(entry: Entry, bytes: Int)] = []
    private var byteCount = 0

    init(maxEntries: Int, maxBytes: Int) {
        self.maxEntries = max(0, maxEntries)
        self.maxBytes = max(0, maxBytes)
    }

    func snapshot() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.map(\.entry)
    }

    func load(completion: @escaping ([Entry]) -> Void) {
        publish(completion)
    }

    func append(_ entry: Entry, completion: (([Entry]) -> Void)? = nil) {
        guard let size = try? JSONEncoder().encode(entry).count,
              size <= maxBytes, maxEntries > 0 else { return }
        lock.lock()
        while !entries.isEmpty && (entries.count >= maxEntries || byteCount + size > maxBytes) {
            byteCount -= entries.removeFirst().bytes
        }
        entries.append((entry, size))
        byteCount += size
        lock.unlock()
        publish(completion)
    }

    func clear(completion: (([Entry]) -> Void)? = nil) {
        lock.lock()
        entries.removeAll()
        byteCount = 0
        lock.unlock()
        publish(completion)
    }

    private func publish(_ completion: (([Entry]) -> Void)?) {
        guard let completion else { return }
        // Read on delivery so pending UI updates do not retain old log buffers.
        DispatchQueue.main.async { completion(self.snapshot()) }
    }
}

/// Owns ordering, loading, byte limits and disk I/O on one queue. UI snapshots are
/// delivered in the same order on main, including clear operations.
final class BoundedLogFile<Entry: Codable> {
    private let queue = DispatchQueue(label: "de.my-wan.dhe.nightguard.log-file", qos: .utility)
    private let fileURL: URL?
    private let maxEntries: Int
    private let maxBytes: Int
    private var entries: [Entry] = []
    private var loaded = false

    init(name: String, maxEntries: Int, maxBytes: Int) {
        self.fileURL = LogStorage.fileURL(name: name)
        self.maxEntries = maxEntries
        self.maxBytes = maxBytes
    }

    // Injectable storage location for isolated tests, including failed writes.
    init(fileURL: URL?, maxEntries: Int, maxBytes: Int) {
        self.fileURL = fileURL
        self.maxEntries = maxEntries
        self.maxBytes = maxBytes
    }

    func load(completion: @escaping ([Entry]) -> Void) {
        queue.async {
            self.loadIfNeeded()
            self.publish(completion)
        }
    }

    func snapshot() -> [Entry] {
        queue.sync {
            loadIfNeeded()
            return entries
        }
    }

    func append(_ entry: Entry, completion: (([Entry]) -> Void)? = nil) {
        queue.async {
            self.loadIfNeeded()
            self.entries.append(entry)
            self.persist()
            self.publish(completion)
        }
    }

    func clear(completion: (([Entry]) -> Void)? = nil) {
        queue.async {
            self.loaded = true
            self.entries.removeAll()
            self.discardFile()
            self.publish(completion)
        }
    }

    private func publish(_ completion: (([Entry]) -> Void)?) {
        guard let completion else { return }
        let snapshot = entries
        DispatchQueue.main.async { completion(snapshot) }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let size = attributes[.size] as? NSNumber, size.intValue <= maxBytes else {
                LogStorage.reportFailure("Discarding oversized log file")
                discardFile()
                return
            }
            let data = try Data(contentsOf: fileURL)
            guard data.count <= maxBytes else { discardFile(); return }
            entries = Array(try JSONDecoder().decode([Entry].self, from: data).suffix(maxEntries))
        } catch {
            LogStorage.reportFailure("Could not load log file; starting empty")
            discardFile()
        }
    }

    private func persist() {
        entries = Array(entries.suffix(maxEntries))
        do {
            var data = try JSONEncoder().encode(entries)
            while data.count > maxBytes && !entries.isEmpty {
                entries.removeFirst()
                data = try JSONEncoder().encode(entries)
            }
            guard let fileURL else { return }
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            LogStorage.reportFailure("Could not save log file; keeping logs in memory")
        }
    }

    private func discardFile() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do { try FileManager.default.removeItem(at: fileURL) }
        catch { LogStorage.reportFailure("Could not remove log file") }
    }
}

/// Swift initializes this once per process, before publishing the suite to callers.
/// Recover the space occupied by old logs before any regular preferences writes.
enum AppGroupPreferences {
    static let defaults: UserDefaults? = {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else { return nil }
        LogStorage.removeLegacyLogs(from: defaults)
        return defaults
    }()
}
