import Foundation

final class ReportDataProvider {
    private var activeTask: NightscoutTask?
    private var cancelled = false
    private let maximumPagesPerWindow = 1000

    func cancel() {
        cancelled = true
        activeTask?.cancel()
        activeTask = nil
    }

    func load(settings: ReportSettings, progress: @escaping (Double) -> Void, completion: @escaping (Result<(ReportRequest, ReportDataset), Error>) -> Void) {
        cancelled = false
        let earliestProfileDate = ReportRequest(settings: settings).start
        loadProfiles(earliest: earliestProfileDate) { result in
            guard !self.cancelled else { return }
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let profiles):
                progress(0.05)
                let activeProfile = profiles.last(where: { $0.effectiveAt <= Date() })
                let request = ReportRequest(settings: settings, timeZone: activeProfile?.timeZone ?? .current)
                self.loadData(request, profiles: profiles, progress: progress, completion: completion)
            }
        }
    }

    private func loadData(_ request: ReportRequest, profiles: [ReportProfile], progress: @escaping (Double) -> Void, completion: @escaping (Result<(ReportRequest, ReportDataset), Error>) -> Void) {
        let windows = stride(from: 0, to: request.days.count, by: 7).map { offset -> (Date, Date) in
            let first = request.days[offset]
            let lastIndex = min(offset + 7, request.days.count)
            return (first, lastIndex == request.days.count ? request.end : request.days[lastIndex])
        }
        var readings: [ReportGlucose] = []
        var treatments: [ReportTreatment] = []

        func fail(_ error: Error) { if !self.cancelled { completion(.failure(error)) } }
        func loadTreatments(_ index: Int) {
            guard !self.cancelled else { return }
            guard index < windows.count else {
                progress(1)
                completion(.success((request, ReportDataset(readings: readings, treatments: treatments, profiles: profiles))))
                return
            }
            let window = windows[index]
            let lookback = index == 0 ? (request.calendar.date(byAdding: .day, value: -1, to: window.0) ?? window.0) : window.0
            self.fetchPages(kind: .treatments, from: lookback, to: window.1) { result in
                switch result {
                case .failure(let error): fail(error)
                case .success(let page):
                    treatments.append(contentsOf: self.decodeTreatments(page, start: lookback, end: window.1))
                    progress(0.50 + 0.50 * Double(index + 1) / Double(windows.count))
                    loadTreatments(index + 1)
                }
            }
        }
        func loadEntries(_ index: Int) {
            guard !self.cancelled else { return }
            guard index < windows.count else { loadTreatments(0); return }
            let window = windows[index]
            self.fetchPages(kind: .entries, from: window.0, to: window.1) { result in
                switch result {
                case .failure(let error): fail(error)
                case .success(let page):
                    readings.append(contentsOf: self.decodeReadings(page, start: window.0, end: window.1))
                    progress(0.05 + 0.45 * Double(index + 1) / Double(windows.count))
                    loadEntries(index + 1)
                }
            }
        }
        loadEntries(0)
    }

    private enum Kind {
        case entries, treatments
        var v3Path: String { self == .entries ? "api/v3/entries" : "api/v3/treatments" }
        var v1Path: String { self == .entries ? "api/v1/entries.json" : "api/v1/treatments.json" }
        var dateField: String { self == .entries ? "date" : "created_at" }
    }

    private func fetchPages(kind: Kind, from start: Date, to end: Date, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        var accumulated: [[String: Any]] = []
        var previousOldest: Double?
        var previousLegacy: Bool?
        let fromMillis = start.timeIntervalSince1970 * 1000
        let toMillis = end.timeIntervalSince1970 * 1000

        func page(_ number: Int) {
            guard !self.cancelled else { return }
            guard number < self.maximumPagesPerWindow else {
                completion(.failure(self.error("The report is too large to retrieve completely.")))
                return
            }
            var query = [
                "\(kind.dateField)$gte": kind == .entries ? String(format: "%.0f", fromMillis) : self.iso(start),
                "\(kind.dateField)$lt": kind == .entries ? String(format: "%.0f", toMillis) : self.iso(end),
                "sort$desc": kind.dateField,
                "limit": "1000"
            ]
            if kind == .entries { query["type$in"] = "sgv|mbg" }
            if number > 0 { query["skip"] = "\(accumulated.count)" }
            let upper: String
            if let previousOldest = previousOldest {
                upper = kind == .entries ? String(format: "%.0f", previousOldest) : self.iso(Date(timeIntervalSince1970: previousOldest / 1000))
            } else {
                upper = kind == .entries ? String(format: "%.0f", toMillis) : self.iso(end)
            }
            let legacy = NightscoutLegacyEndpoint(path: kind.v1Path, query: [
                "find[\(kind.dateField)][$gte]": kind == .entries ? String(format: "%.0f", fromMillis) : self.iso(start),
                "find[\(kind.dateField)][$lt]": upper,
                "count": "1000"
            ])
            self.activeTask = NightscoutAPIClient.shared.requestV3(path: kind.v3Path, query: query, legacy: legacy, readTimeout: 45) { result in
                DispatchQueue.main.async {
                    guard !self.cancelled else { return }
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success(let response):
                        guard let items = try? JSONSerialization.jsonObject(with: response.0) as? [[String: Any]] else {
                            completion(.failure(self.error("Nightscout returned invalid report data.")))
                            return
                        }
                        let isLegacy = response.1.url?.path.contains("/api/v1/") == true
                        if previousLegacy != nil && previousLegacy != isLegacy {
                            completion(.failure(self.error("The Nightscout API changed during the report download.")))
                            return
                        }
                        previousLegacy = isLegacy
                        if items.isEmpty { completion(.success(accumulated)); return }
                        let timestamps = items.compactMap { self.timestamp($0, field: kind.dateField) }
                        guard let oldest = timestamps.min(), previousOldest.map({ oldest < $0 }) ?? true else {
                            completion(.failure(self.error("Nightscout stopped advancing through report data.")))
                            return
                        }
                        previousOldest = oldest
                        accumulated.append(contentsOf: items)
                        if oldest < fromMillis { completion(.success(accumulated)); return }
                        page(number + 1)
                    }
                }
            }
        }
        page(0)
    }

    private func loadProfiles(earliest: Date, completion: @escaping (Result<[ReportProfile], Error>) -> Void) {
        var accumulated: [[String: Any]] = []
        var previousOldest: Double?
        func page(_ number: Int) {
            guard !self.cancelled else { return }
            guard number < 100 else {
                completion(.failure(self.error("The report is too large to retrieve completely.")))
                return
            }
            var query = ["count": "1000"]
            if let oldest = previousOldest {
                query["find[startDate][$lt]"] = self.iso(Date(timeIntervalSince1970: oldest / 1000))
            }
            self.activeTask = NightscoutAPIClient.shared.requestLegacy(path: "api/v1/profile.json", query: query) { result in
                DispatchQueue.main.async {
                    guard !self.cancelled else { return }
                    switch result {
                    case .failure(let error):
                        // Glucose-only reports remain available if profiles are unavailable.
                        if number == 0 { completion(.success([])) }
                        else { completion(.failure(error)) }
                    case .success(let response):
                        guard let rows = try? JSONSerialization.jsonObject(with: response.0) as? [[String: Any]] else {
                            completion(.failure(self.error("Nightscout returned invalid report data.")))
                            return
                        }
                        if rows.isEmpty { completion(.success(self.decodeProfiles(accumulated))); return }
                        guard let oldest = rows.compactMap({ self.timestamp($0, field: "startDate") }).min(),
                              previousOldest.map({ oldest < $0 }) ?? true else {
                            completion(.failure(self.error("Nightscout stopped advancing through report data.")))
                            return
                        }
                        accumulated.append(contentsOf: rows)
                        previousOldest = oldest
                        if oldest <= earliest.timeIntervalSince1970 * 1000 {
                            completion(.success(self.decodeProfiles(accumulated)))
                        } else {
                            page(number + 1)
                        }
                    }
                }
            }
        }
        page(0)
    }

    private func decodeReadings(_ rows: [[String: Any]], start: Date, end: Date) -> [ReportGlucose] {
        var seen = Set<String>()
        return rows.compactMap { row -> ReportGlucose? in
            guard let millis = timestamp(row, field: "date"), let value = number(row["sgv"] ?? row["mbg"]),
                  value.isFinite, value > 10 else { return nil }
            let date = Date(timeIntervalSince1970: millis / 1000)
            guard date >= start && date < end else { return nil }
            let isMeter = row["sgv"] == nil
            let key = "\(Int64(millis))-\(isMeter)-\(value)"
            guard seen.insert(key).inserted else { return nil }
            return ReportGlucose(date: date, value: value, isMeter: isMeter)
        }.sorted { $0.date < $1.date }
    }

    private func decodeTreatments(_ rows: [[String: Any]], start: Date, end: Date) -> [ReportTreatment] {
        var seen = Set<String>()
        return rows.compactMap { row -> ReportTreatment? in
            guard let millis = timestamp(row, field: "created_at") else { return nil }
            let date = Date(timeIntervalSince1970: millis / 1000)
            guard date >= start && date < end else { return nil }
            let kind = row["eventType"] as? String ?? ""
            let key = (row["_id"] as? String) ?? (row["identifier"] as? String) ?? String(data: (try? JSONSerialization.data(withJSONObject: row, options: .sortedKeys)) ?? Data(), encoding: .utf8) ?? UUID().uuidString
            guard seen.insert(key).inserted else { return nil }
            return ReportTreatment(date: date, kind: kind, carbs: number(row["carbs"]) ?? 0,
                                   insulin: number(row["insulin"]) ?? 0, duration: number(row["duration"]) ?? 0,
                                   rate: number(row["absolute"]) ?? number(row["rate"]), percent: number(row["percent"]),
                                   profileName: row["profile"] as? String)
        }.sorted { $0.date < $1.date }
    }

    private func decodeProfiles(_ rows: [[String: Any]]) -> [ReportProfile] {
        rows.flatMap { row -> [ReportProfile] in
            guard let start = timestamp(row, field: "startDate"),
                  let store = row["store"] as? [String: Any] else { return [] }
            let defaultName = row["defaultProfile"] as? String ?? "Default"
            let zoneName = row["timezone"] as? String ?? ""
            let zone = TimeZone(identifier: zoneName) ?? .current
            return store.compactMap { name, raw -> ReportProfile? in
                guard let data = raw as? [String: Any] else { return nil }
                let units = ((data["units"] as? String) ?? (row["units"] as? String) ?? "mg/dl").lowercased()
                let glucoseScale = units.contains("mmol") ? 18.0182 : 1.0
                return ReportProfile(name: name, isDefault: name == defaultName,
                                     effectiveAt: Date(timeIntervalSince1970: start / 1000), timeZone: (data["timezone"] as? String).flatMap(TimeZone.init(identifier:)) ?? zone,
                                     dia: number(data["dia"]), carbsPerHour: number(data["carbs_hr"]),
                                     basal: schedule(data["basal"]), carbRatio: schedule(data["carbratio"]),
                                     sensitivity: schedule(data["sens"]).map { ReportSchedulePoint(minutes: $0.minutes, value: $0.value * glucoseScale) },
                                     targetLow: schedule(data["target_low"]).map { ReportSchedulePoint(minutes: $0.minutes, value: $0.value * glucoseScale) },
                                     targetHigh: schedule(data["target_high"]).map { ReportSchedulePoint(minutes: $0.minutes, value: $0.value * glucoseScale) })
            }
        }.sorted { $0.effectiveAt < $1.effectiveAt }
    }

    private func schedule(_ raw: Any?) -> [ReportSchedulePoint] {
        ((raw as? [[String: Any]]) ?? []).compactMap { row -> ReportSchedulePoint? in
            guard let value = number(row["value"]) else { return nil }
            let minutes: Int
            if let time = row["time"] as? String {
                let parts = time.split(separator: ":")
                minutes = parts.count == 2 ? (Int(parts[0]) ?? 0) * 60 + (Int(parts[1]) ?? 0) : 0
            } else {
                minutes = Int((number(row["timeAsSeconds"]) ?? 0) / 60)
            }
            return ReportSchedulePoint(minutes: minutes, value: value)
        }.sorted { $0.minutes < $1.minutes }
    }

    private func timestamp(_ row: [String: Any], field: String) -> Double? {
        if let value = number(row[field]) { return value < 10_000_000_000 ? value * 1000 : value }
        if field == "date", let value = number(row["mills"]) { return value }
        guard let string = row[field] as? String ?? row["dateString"] as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
        return parsed.map { $0.timeIntervalSince1970 * 1000 }
    }

    private func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    private func error(_ message: String) -> Error { NSError(domain: "NightguardReport", code: 1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(message, comment: "Report error")]) }
}
