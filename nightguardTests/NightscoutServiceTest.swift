//
//  ServiceBoundaryTest.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 25.04.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

import XCTest
import PDFKit

private final class NightscoutMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "NightscoutMockURLProtocol", code: -1))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class ReportCalculationTest: XCTestCase {
    private func request() -> ReportRequest {
        var settings = ReportSettings()
        settings.period = ReportPeriod.day.rawValue
        let now = ISO8601DateFormatter().date(from: "2026-10-11T12:00:00Z")!
        return ReportRequest(settings: settings, timeZone: TimeZone(secondsFromGMT: 0)!, now: now)
    }

    func testFiveMinuteInterpolationIncludesFirstMidnightValueAndPreservesLongGaps() {
        let report = request()
        let readings = [
            ReportGlucose(date: report.start.addingTimeInterval(3 * 60), value: 62, isMeter: false),
            ReportGlucose(date: report.start.addingTimeInterval(10 * 60), value: 72, isMeter: false),
            ReportGlucose(date: report.start.addingTimeInterval(30 * 60), value: 80, isMeter: false)
        ]
        let samples = ReportCalculator.normalizedReadings(readings, request: report)
        XCTAssertEqual(samples.map(\.value), [62, 64, 72, 80])
        XCTAssertEqual(samples.map { Int($0.date.timeIntervalSince(report.start) / 60) }, [0, 5, 10, 30])
    }

    func testTemporaryBasalPercentIsRelativeToProfileRateAndExpiresAtExactTime() {
        let report = request()
        let profile = ReportProfile(name: "Default", isDefault: true,
                                    effectiveAt: report.start.addingTimeInterval(-86400), timeZone: TimeZone(secondsFromGMT: 0)!,
                                    dia: nil, carbsPerHour: nil,
                                    basal: [ReportSchedulePoint(minutes: 0, value: 2)],
                                    carbRatio: [], sensitivity: [], targetLow: [], targetHigh: [])
        let treatments = [
            ReportTreatment(date: report.start.addingTimeInterval(3600), kind: "Temp Basal", carbs: 0, insulin: 0,
                            duration: 30, rate: nil, percent: -100, profileName: nil),
            ReportTreatment(date: report.start.addingTimeInterval(7200), kind: "Temp Basal", carbs: 0, insulin: 0,
                            duration: 30, rate: nil, percent: 50, profileName: nil)
        ]
        let series = ReportCalculator.basalSeriesForDay(report.start, end: report.end,
                                                        profiles: [profile], treatments: treatments)!
        let delivered = series.reduce(0) { $0 + $1.deliveredRate * $1.end.timeIntervalSince($1.date) / 3600 }
        XCTAssertEqual(delivered, 47.5, accuracy: 0.0001)
    }
    private func event(_ minutes: Double, kind: String = "Meal Bolus", carbs: Double = 0,
                       insulin: Double = 0, duration: Double = 0, smb: Bool = false,
                       low: Double? = nil, high: Double? = nil) -> ReportTreatment {
        ReportTreatment(date: request().start.addingTimeInterval(minutes * 60), kind: kind,
                        carbs: carbs, insulin: insulin, duration: duration, rate: nil, percent: nil,
                        profileName: nil, isSMB: smb, targetLow: low, targetHigh: high)
    }

    private func profile() -> ReportProfile {
        ReportProfile(name: "Default", isDefault: true, effectiveAt: request().start.addingTimeInterval(-86400),
                      timeZone: TimeZone(secondsFromGMT: 0)!, dia: 5, carbsPerHour: 20,
                      basal: [ReportSchedulePoint(minutes: 0, value: 2)], carbRatio: [], sensitivity: [],
                      targetLow: [ReportSchedulePoint(minutes: 0, value: 120)],
                      targetHigh: [ReportSchedulePoint(minutes: 0, value: 120)])
    }

    func testReportRangeIsIndependentOfAlarmSettingsAndUnits() {
        let low = UserDefaultsRepository.lowerBound.value
        let high = UserDefaultsRepository.upperBound.value
        defer { UserDefaultsRepository.lowerBound.value = low; UserDefaultsRepository.upperBound.value = high }
        UserDefaultsRepository.lowerBound.value = 50
        UserDefaultsRepository.upperBound.value = 250
        let report = ReportRequest(settings: ReportSettings(), unit: .mmol, locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(report.low, 80)
        XCTAssertEqual(report.high, 180)
        XCTAssertEqual(report.displayGlucose(report.low), "4,4")
        XCTAssertEqual(report.displayGlucose(report.high), "10,0")
        let counts = ReportCalculator.classify([79, 80, 179, 180], low: report.low, high: report.high)
        XCTAssertEqual(counts.low, 1); XCTAssertEqual(counts.inRange, 2); XCTAssertEqual(counts.high, 1)
    }

    func testPercentageRoundingPreservesOneHundredAndReferenceDistribution() {
        let distribution = ReportDistribution(low: 206, inRange: 1510, high: 286)
        XCTAssertEqual(distribution.percent(.low), "10%")
        XCTAssertEqual(distribution.percent(.inRange), "76%")
        XCTAssertEqual(distribution.percent(.high), "14%")
        XCTAssertEqual(ReportDistribution(low: 0, inRange: 0, high: 0).percent(.inRange), "–")
        XCTAssertEqual(ReportFormatting.number(7.65, digits: 1, locale: Locale(identifier: "de_DE")), "7,7")
        XCTAssertEqual(ReportFormatting.number(39.45, digits: 1, locale: Locale(identifier: "de_DE")), "39,5")
    }

    func testNinetyDayPDFIncludesEveryDayAndMissingDataPages() throws {
        var settings = ReportSettings()
        settings.period = 90
        let report = ReportRequest(settings: settings, timeZone: TimeZone(identifier: "Europe/Berlin")!,
                                   now: ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z")!)
        let analysis = ReportCalculator.calculate(ReportDataset(readings: [], treatments: [], profiles: []), request: report)
        let url = try ReportPDFRenderer().render(request: report, analysis: analysis)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertEqual(document.pageCount, 22)
        let text = try XCTUnwrap(document.string)
        for day in report.days { XCTAssertTrue(text.contains(report.dateText(day, format: "EEE, dd.MM.yyyy"))) }
    }

    func testWizardDeduplicationIsSharedByTotalsAndAnnotationsAndKeepsSMB() {
        let events = [event(10, insulin: 5.6), event(11, kind: "Bolus Wizard", carbs: 60, insulin: 5.6),
                      event(20, insulin: 0.4, smb: true)]
        let analysis = ReportCalculator.calculate(ReportDataset(readings: [], treatments: events, profiles: [profile()]), request: request())
        let day = analysis.days[0]
        XCTAssertEqual(day.carbs, 60)
        XCTAssertEqual(day.bolus, 6, accuracy: 0.00001)
        XCTAssertEqual(day.treatments.filter { !$0.isSMB }.reduce(0) { $0 + $1.insulin }, 5.6)
        let labels = ReportCalculator.annotations(day.treatments.filter { !$0.isSMB }, field: \.insulin)
        XCTAssertEqual(labels.count, 1); XCTAssertEqual(labels[0].value, 5.6); XCTAssertEqual(labels[0].count, 1)
    }

    func testAnnotationsGroupFromFirstEventWithoutChainingAndSortInput() {
        let labels = ReportCalculator.annotations([event(80, carbs: 30), event(0, carbs: 10), event(40, carbs: 20)], field: \.carbs)
        XCTAssertEqual(labels.map(\.value), [30, 30])
        XCTAssertEqual(labels.map(\.count), [2, 1])
        XCTAssertEqual(labels[1].date, request().start.addingTimeInterval(80 * 60))
        XCTAssertEqual(ReportCalculator.annotations([event(0, carbs: 1), event(60, carbs: 2)], field: \.carbs).count, 2)
    }

    func testTemporaryTargetsCarryAcrossMidnightExpireAndCancelWithoutRevivingOldTarget() {
        let report = request()
        let events = [event(-30, kind: "Temporary Target", duration: 90, low: 150, high: 160),
                      event(30, kind: "Temporary Target", duration: 10, low: 90, high: 100),
                      event(50, kind: "Temporary Target", duration: 20, low: 140, high: 140),
                      event(55, kind: "Temporary Target", duration: 0)]
        let series = ReportCalculator.targetSeriesForDay(report.start, end: report.end, profiles: [profile()], treatments: events)
        XCTAssertEqual(series.map(\.low), [150, 90, 120, 140, 120])
        XCTAssertEqual(series.map { Int($0.date.timeIntervalSince(report.start) / 60) }, [0, 30, 40, 50, 55])
        XCTAssertEqual(series.last?.end, report.end)
    }

    func testDecoderPreservesSMBAndConvertsTemporaryTargetUnits() {
        let report = request()
        let rows: [[String: Any]] = [
            ["_id": "1", "created_at": report.start.timeIntervalSince1970 * 1000, "eventType": "Correction Bolus", "type": "smb", "insulin": 0.3],
            ["_id": "2", "created_at": report.start.timeIntervalSince1970 * 1000, "eventType": "Temporary Target", "units": "mmol/L", "targetBottom": 5.5, "targetTop": 6.5, "duration": 30],
            ["_id": "3", "created_at": report.start.timeIntervalSince1970 * 1000, "eventType": "Correction Bolus", "isSMB": true]
        ]
        let events = ReportDataProvider().decodeTreatments(rows, start: report.start, end: report.end)
        XCTAssertEqual(events.filter(\.isSMB).count, 2)
        let target = events.first { $0.kind == "Temporary Target" }!
        XCTAssertEqual(target.targetLow!, 5.5 * ReportRequest.mmolFactor, accuracy: 0.00001)
        XCTAssertEqual(target.targetHigh!, 6.5 * ReportRequest.mmolFactor, accuracy: 0.00001)
    }

    func testCGPAndInsulinStatisticsDoNotChangeWithDisplayUnit() {
        let report = request()
        let readings = (0..<288).map { ReportGlucose(date: report.start.addingTimeInterval(Double($0) * 300), value: $0 % 2 == 0 ? 65 : 190, isMeter: false) }
        let data = ReportDataset(readings: readings, treatments: [event(40, insulin: 3)], profiles: [profile()])
        let mg = ReportCalculator.calculate(data, request: report)
        let mmolRequest = ReportRequest(settings: report.settings, timeZone: report.calendar.timeZone,
                                        now: report.end.addingTimeInterval(3600), unit: .mmol)
        let mmol = ReportCalculator.calculate(data, request: mmolRequest)
        XCTAssertEqual(mg.pgr, mmol.pgr)
        XCTAssertEqual(mg.days[0].totalInsulin, mmol.days[0].totalInsulin)
        XCTAssertEqual(ReportCalculator.cgpReference[4], 90)
        XCTAssertEqual(ReportCalculator.scaleCGP(90, axis: 4), 14)
        XCTAssertEqual(ReportFormatting.number(mmolRequest.displayValue(43.5), digits: 1, locale: Locale(identifier: "de_DE")), "2,4")
    }

    func testPDFRendersBothUnitsAndPaginatesLongProfilesWithoutDroppingIntervals() throws {
        var settings = request().settings
        settings.name = String(repeating: "Long name ", count: 20)
        settings.birthDate = request().start
        settings.diabetesSince = "2012"
        settings.insulin = "Example"
        let points = (0..<48).map { ReportSchedulePoint(minutes: $0 * 30, value: Double($0 + 1)) }
        let longProfile = ReportProfile(name: "Long schedule", isDefault: true, effectiveAt: request().start,
            timeZone: request().calendar.timeZone, dia: 5, carbsPerHour: 20, basal: points,
            carbRatio: [], sensitivity: [], targetLow: profile().targetLow, targetHigh: profile().targetHigh)
        for unit in [Units.mmol, .mgdl] {
            let report = ReportRequest(settings: settings, timeZone: request().calendar.timeZone,
                                       now: request().end.addingTimeInterval(3600), unit: unit, locale: Locale(identifier: "de_DE"))
            let readings = [ReportGlucose(date: report.start, value: 120, isMeter: false),
                            ReportGlucose(date: report.start.addingTimeInterval(300), value: 120, isMeter: false)]
            let analysis = ReportCalculator.calculate(ReportDataset(readings: readings, treatments: [], profiles: [longProfile]), request: report)
            let url = try ReportPDFRenderer().render(request: report, analysis: analysis)
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let document = try XCTUnwrap(PDFDocument(url: url))
            XCTAssertGreaterThanOrEqual(document.pageCount, 7)
            let text = try XCTUnwrap(document.string)
            XCTAssertTrue(text.contains("23:30–24:00"))
            XCTAssertTrue(text.contains(report.glucoseUnit))
            XCTAssertTrue(text.contains(unit == .mmol ? "6,7" : "120"))
        }
    }

}

class NightscoutServiceTest: XCTestCase {
    private var originalForceV1API = false

    override func setUp() {
        super.setUp()
        originalForceV1API = UserDefaultsRepository.forceV1API.value
        UserDefaultsRepository.forceV1API.value = false
    }

    override func tearDown() {
        UserDefaultsRepository.forceV1API.value = originalForceV1API
        super.tearDown()
    }

    func testForcedV1StatisticsPaginatesWithoutCapabilityCheck() throws {
        UserDefaultsRepository.forceV1API.value = true
        try checkStatisticsPagination(versionStatus: 404, forbidVersionCheck: true, pageSize: 730)
    }

    func testForcedV1SkipsAuthorizationAndPreservesTreatmentRequests() throws {
        let restore = useTemporaryCredentials(url: "https://forced.example.org/nightscout", token: "reader+secret")
        defer { restore() }
        UserDefaultsRepository.forceV1API.value = true
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        var paths: [String] = []
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            paths.append(url.path)
            XCTAssertEqual(url.path, "/nightscout/api/v1/treatments")
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertEqual(query.first { $0.name == "token" }?.value, "reader+secret")
            XCTAssertEqual(query.first { $0.name == "count" }?.value, "5")
            if request.httpMethod == "POST" {
                var body = request.httpBody
                if body == nil, let stream = request.httpBodyStream {
                    stream.open()
                    defer { stream.close() }
                    var data = Data()
                    var buffer = [UInt8](repeating: 0, count: 1024)
                    while stream.hasBytesAvailable {
                        let count = stream.read(&buffer, maxLength: buffer.count)
                        if count <= 0 { break }
                        data.append(buffer, count: count)
                    }
                    body = data
                }
                XCTAssertEqual(body, Data("{\"carbs\":10}".utf8))
            }
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("[]".utf8))
        }
        defer { NightscoutMockURLProtocol.handler = nil }
        for method in ["GET", "POST"] {
            let finished = expectation(description: method)
            _ = client.requestV3(path: "api/v3/treatments", method: method,
                body: method == "POST" ? Data("{\"carbs\":10}".utf8) : nil,
                legacy: NightscoutLegacyEndpoint(path: "api/v1/treatments", query: ["count": "5"]),
                allowLegacyFallback: false) { result in
                if case .failure(let error) = result { XCTFail("Unexpected error: \(error)") }
                finished.fulfill()
            }
            waitForExpectations(timeout: 2)
        }
        XCTAssertEqual(paths.count, 2)
    }

    func testForcedV1DisplayCompletesWithOneRequestForFreshStaleEmptyAndFailedResponses() throws {
        let restore = useTemporaryCredentials(url: "https://display.example.org", token: "")
        defer { restore() }
        UserDefaultsRepository.forceV1API.value = true
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        defer { NightscoutMockURLProtocol.handler = nil }
        for age: TimeInterval in [0, 3600, -1, -2] {
            var requests = 0
            NightscoutMockURLProtocol.handler = { request in
                requests += 1
                let url = try XCTUnwrap(request.url)
                XCTAssertEqual(url.path, "/api/v1/entries.json")
                let data = age < 0 ? Data("[]".utf8) : try JSONSerialization.data(withJSONObject: [
                    ["date": Date().addingTimeInterval(-age).timeIntervalSince1970 * 1000, "sgv": 123]
                ])
                return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: age == -2 ? 401 : 200, httpVersion: nil, headerFields: nil)), data)
            }
            let finished = expectation(description: "direct display \(age)")
            finished.assertForOverFulfill = true
            _ = NightscoutService.singleton.readLatestEntriesHybrid(apiClient: client) { result in
                switch result {
                case .data(let records):
                    XCTAssertNotEqual(age, -2)
                    XCTAssertEqual(records.count, age == -1 ? 0 : 1)
                case .error:
                    XCTAssertEqual(age, -2)
                }
                finished.fulfill()
            }
            waitForExpectations(timeout: 2)
            XCTAssertEqual(requests, 1)
        }
    }

    func testForcedV1RejectsMissingLegacyEndpointWithoutNetworkRequest() {
        let restore = useTemporaryCredentials(url: "https://missing.example.org", token: "")
        defer { restore() }
        UserDefaultsRepository.forceV1API.value = true
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        NightscoutMockURLProtocol.handler = { _ in
            XCTFail("Forced V1 must not make a V3 request")
            throw URLError(.unsupportedURL)
        }
        defer { NightscoutMockURLProtocol.handler = nil }
        let finished = expectation(description: "missing legacy endpoint")
        _ = client.requestV3(path: "api/v3/entries") { result in
            guard case .failure(let error) = result else { return XCTFail("Expected failure") }
            XCTAssertEqual((error as NSError).code, NSURLErrorUnsupportedURL)
            finished.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testAPIModeIsPersistedAndIncludedInWatchSyncInBothDirections() {
        UserDefaultsRepository.initializeSyncValues()
        XCTAssertTrue(UserDefaultsRepository.forceV1API.defaultValue)
        for enabled in [true, false] {
            UserDefaultsRepository.forceV1API.value = enabled
            let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
            XCTAssertEqual(defaults.bool(forKey: "forceV1API"), enabled)
            let freshValue = UserDefaultsValue<Bool>(key: "forceV1API", default: false)
            XCTAssertEqual(freshValue.value, enabled)
            XCTAssertTrue(UserDefaultsValueGroups.values(from: UserDefaultsValueGroups.GroupNames.watchSync)?.contains { $0.key == "forceV1API" } == true)
        }
    }


    func testStatisticsLoadsAllFiveDaysThroughV1Fallback() throws {
        try checkStatisticsPagination(versionStatus: 404)
    }

    func testStatisticsPaginatesV3WithFallbackEnabled() throws {
        try checkStatisticsPagination(versionStatus: 200)
    }

    func testStatisticsFallsBackAfterCapabilityTimeout() throws {
        try checkStatisticsPagination(versionStatus: nil)
    }

    private func checkStatisticsPagination(versionStatus: Int?, forbidVersionCheck: Bool = false, pageSize: Int = 1000) throws {
        let restore = useTemporaryCredentials(url: "https://statistics.example.org", token: "")
        defer { restore() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let service = NightscoutService(statisticsClient: NightscoutAPIClient(session: URLSession(configuration: configuration)))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: TimeService.getToday())
        let start = try XCTUnwrap(calendar.date(byAdding: .day, value: -4, to: today))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))
        let from = start.timeIntervalSince1970 * 1000
        let to = end.timeIntervalSince1970 * 1000
        let timestamps = Array(stride(from: from, to: to, by: 60_000)).reversed().map { $0 }
        // A server may impose a smaller cap than requested.
        var offsets: [Int] = []
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path == "/api/v3/version" {
                XCTAssertFalse(forbidVersionCheck, "Forced V1 must skip the capability check")
                guard let versionStatus else { throw URLError(.timedOut) }
                return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: versionStatus, httpVersion: nil, headerFields: nil)), Data())
            }
            let legacy = versionStatus != 200
            XCTAssertEqual(url.path, legacy ? "/api/v1/entries.json" : "/api/v3/entries")
            let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(Double(query[legacy ? "find[date][$gte]" : "date$gte"] ?? ""), from)
            let upperBound = try XCTUnwrap(Double(query[legacy ? "find[date][$lt]" : "date$lt"] ?? ""))
            let skip: Int
            if legacy {
                XCTAssertNil(query["skip"], "V1 ignores skip; pagination must advance the date bound")
                XCTAssertEqual(upperBound, offsets.isEmpty ? to : timestamps[min(offsets.last! + pageSize, timestamps.count) - 1])
                skip = timestamps.prefix { $0 >= upperBound }.count
            } else {
                XCTAssertEqual(upperBound, to)
                skip = Int(query["skip"] ?? "0") ?? 0
            }
            offsets.append(skip)
            let entries: [[String: Any]] = timestamps.dropFirst(skip).prefix(pageSize).map {
                ["date": $0, "sgv": 120, "type": "sgv"]
            }
            let payload: Any = legacy ? entries : ["result": entries]
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), try JSONSerialization.data(withJSONObject: payload))
        }
        defer { NightscoutMockURLProtocol.handler = nil }
        let completed = expectation(description: "complete five-day statistics")
        _ = service.readStatisticsDays { result in
            switch result {
            case .error(let error): XCTFail("Statistics failed: \(error)")
            case .data(let days):
                XCTAssertEqual(days.count, 5)
                XCTAssertEqual(days.flatMap { $0 }.count, timestamps.count)
                XCTAssertEqual(days.last?.first?.timestamp, from)
                for index in 0..<5 {
                    let dayStart = calendar.date(byAdding: .day, value: -index, to: today)!
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                    XCTAssertEqual(days[index].count, Int(dayEnd.timeIntervalSince(dayStart) / 60))
                }
            }
            completed.fulfill()
        }
        waitForExpectations(timeout: 10)
        XCTAssertEqual(offsets, Array(stride(from: 0, to: timestamps.count, by: pageSize)))
    }

    func testAuthenticationErrorsIncludeDiagnosticStageAndJWTSource() {
        let cases: [(NightscoutAuthenticationStage, String)] = [
            (.version, "NS401-VERSION"),
            (.jwt, "NS401-JWT"),
            (.renew, "NS401-RENEW"),
            (.retry, "NS401-RETRY"),
            (.noToken, "NS401-NONE"),
            (.legacy, "NS401-V1")
        ]

        for (stage, code) in cases {
            let error = NightscoutHTTPError(statusCode: 401, endpoint: "/test", authenticationStage: stage)
            XCTAssertTrue(error.localizedDescription.contains(code), "Expected \(code) in \(error.localizedDescription)")
            XCTAssertTrue(error.localizedDescription.contains("HTTP 401"))
        }

        let cachedError = NightscoutHTTPError(
            statusCode: 401,
            endpoint: "/test",
            authenticationStage: .retry,
            previousJWTSource: .cached
        )
        XCTAssertTrue(cachedError.localizedDescription.contains(NightscoutJWTSource.cached.message))

        let freshError = NightscoutHTTPError(
            statusCode: 401,
            endpoint: "/test",
            authenticationStage: .renew,
            previousJWTSource: .fresh
        )
        XCTAssertTrue(freshError.localizedDescription.contains(NightscoutJWTSource.fresh.message))
    }

    func testJWTResponseErrorsHaveDistinctDiagnosticCodes() {
        XCTAssertTrue(NightscoutJWTResponseError.expired.localizedDescription.contains("NSJWT-EXPIRED"))
        XCTAssertTrue(NightscoutJWTResponseError.unusable.localizedDescription.contains("NSJWT-RESPONSE"))
    }

    func testHybridEntriesWaitsForFreshFallbackWhenV3HeadIsStale() {
        let staleTimestamp = Date().addingTimeInterval(-40 * 60).timeIntervalSince1970 * 1000
        let freshTimestamp = Date().addingTimeInterval(-2 * 60).timeIntervalSince1970 * 1000
        let stale = NightscoutEntryRecord(dateMillis: staleTimestamp, type: "sgv", sgv: 110)
        let fresh = NightscoutEntryRecord(dateMillis: freshTimestamp, type: "sgv", sgv: 125)
        let expectation = expectation(description: "fresh hybrid result")
        var completionCount = 0

        let accumulator = HybridEntriesAccumulator { result, source in
            completionCount += 1
            guard case .data(let records) = result else {
                XCTFail("Expected a successful hybrid result")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(source, "v3+v1")
            XCTAssertEqual(records.last?.sgv, 125)
            expectation.fulfill()
        }

        accumulator.receive(.data([stale]), source: "v3")
        XCTAssertEqual(completionCount, 0)
        accumulator.receive(.data([fresh]), source: "v1")

        waitForExpectations(timeout: 1)
        XCTAssertEqual(completionCount, 1)
    }

    func testHybridEntriesUsesNewestConfirmedStaleValueFromBothAPIs() {
        let older = NightscoutEntryRecord(
            dateMillis: Date().addingTimeInterval(-45 * 60).timeIntervalSince1970 * 1000,
            type: "sgv",
            sgv: 110
        )
        let newer = NightscoutEntryRecord(
            dateMillis: Date().addingTimeInterval(-35 * 60).timeIntervalSince1970 * 1000,
            type: "sgv",
            sgv: 115
        )
        let expectation = expectation(description: "confirmed stale hybrid result")

        let accumulator = HybridEntriesAccumulator { result, source in
            guard case .data(let records) = result else {
                XCTFail("Expected stale server data to remain available for no-data alarms")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(source, "v3+v1")
            XCTAssertEqual(records.max(by: { $0.dateMillis < $1.dateMillis })?.sgv, 115)
            expectation.fulfill()
        }

        accumulator.receive(.data([older]), source: "v3")
        accumulator.receive(.data([newer]), source: "v1")

        waitForExpectations(timeout: 1)
    }

    func testEntriesHeadParserKeepsSGVAndManualMeterValues() throws {
        let payload = Data("""
        [
          {"identifier":"sgv-1","date":1724198400000,"type":"sgv","sgv":123,"direction":"Flat","units":"mg/dL"},
          {"_id":"mbg-1","date":"2024-08-21T00:00:00.000Z","type":"mbg","mbg":137},
          {"date":1724198401000,"type":"unknown"}
        ]
        """.utf8)

        let records = try NightscoutService.singleton.parseEntryRecords(from: payload)

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first?.storageKey, "sgv-1")
        XCTAssertEqual(records.first?.sgv, 123)
        XCTAssertEqual(records.first?.direction, "Flat")
        XCTAssertEqual(records.last?.storageKey, "mbg-1")
        XCTAssertEqual(records.last?.mbg, 137)
        XCTAssertNil(records.last?.sgv)
    }

    func testEntriesHeadParserAcceptsDateStringAndMongoExtendedDates() throws {
        let payload = Data("""
        [
          {"dateString":"2024-08-21T00:00:00.000Z","type":"sgv","sgv":140},
          {"date":{"$date":{"$numberLong":"1724198401000"}},"type":"sgv","sgv":141}
        ]
        """.utf8)

        let records = try NightscoutService.singleton.parseEntryRecords(from: payload)

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.compactMap(\.sgv), [140.0, 141.0])
        XCTAssertEqual(records.map(\.dateMillis), [1724198400000.0, 1724198401000.0])
    }

    func testEntryRecordFallbackKeyAllowsCorrectionsAtSameTimestamp() {
        let original = NightscoutEntryRecord(dateMillis: 1724198400000, type: "sgv", sgv: 120)
        let correction = NightscoutEntryRecord(dateMillis: 1724198400000, type: "sgv", sgv: 125)

        XCTAssertEqual(original.storageKey, correction.storageKey)
        XCTAssertNotEqual(original.sgv, correction.sgv)
    }

    func testEntryRecordKeyDoesNotTrapOnOutOfRangeTimestamp() {
        let record = NightscoutEntryRecord(dateMillis: Double.greatestFiniteMagnitude, type: "sgv", sgv: 120)

        XCTAssertTrue(record.storageKey.hasPrefix("sgv:"))
    }

    func testEntryRecordNormalizesNightscoutDirectionForWidgets() {
        let record = NightscoutEntryRecord(
            dateMillis: 1724198400000,
            type: "sgv",
            sgv: 120,
            direction: "FortyFiveUp"
        )

        XCTAssertEqual(record.bloodSugar?.arrow, "↗")
    }

    func testV3URLConstructionPreservesServerSubpathAndFilterValues() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://example.org/nightscout"))
        let url = try XCTUnwrap(NightscoutAPIClient.shared.makeURL(
            baseURL: baseURL,
            path: "api/v3/entries",
            query: [
                "date$gt": "1724198400000",
                "type$in": "sgv|mbg",
                "sort$desc": "date"
            ]
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(components.path, "/nightscout/api/v3/entries")
        XCTAssertEqual(query["date$gt"], "1724198400000")
        XCTAssertEqual(query["type$in"], "sgv|mbg")
        XCTAssertEqual(query["sort$desc"], "date")
        XCTAssertEqual(query["token"], "care-secret")
    }

    func testV3URLConstructionRemovesLegacyTokenFromBaseURL() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://example.org/ns?token=secret&tenant=one"))
        let url = try XCTUnwrap(NightscoutAPIClient.shared.makeURL(baseURL: baseURL, path: "api/v3/status", query: [:]))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(query["tenant"], "one")
        XCTAssertEqual(query["token"], "care-secret")
    }

    func testFallsBackToV1WhenV3IsUnavailable() throws {
        let restoreCredentials = useTemporaryCredentials(url: "https://fallback.example.org/nightscout", token: "")
        defer { restoreCredentials() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        var requestedPaths: [String] = []
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            requestedPaths.append(url.path)
            let status = url.path.hasSuffix("/api/v3/version") ? 404 : 200
            let data = url.path.hasSuffix("/api/v1/entries.json") ? Data("[{\"sgv\":123}]".utf8) : Data()
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)), data)
        }
        defer { NightscoutMockURLProtocol.handler = nil }

        let expectation = expectation(description: "v1 fallback completed")
        _ = client.requestV3(
            path: "api/v3/entries",
            legacy: NightscoutLegacyEndpoint(path: "api/v1/entries.json", query: ["count": "1"])
        ) { result in
            if case .success(let response) = result {
                XCTAssertEqual(String(data: response.0, encoding: .utf8), "[{\"sgv\":123}]")
            } else {
                XCTFail("Expected a successful v1 fallback")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(requestedPaths, ["/nightscout/api/v3/version", "/nightscout/api/v1/entries.json"])
    }

    func testFallsBackToV1WhenV3CapabilityCheckTimesOut() throws {
        let restoreCredentials = useTemporaryCredentials(url: "https://timeout.example.org", token: "")
        defer { restoreCredentials() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path.hasSuffix("/api/v3/version") {
                throw URLError(.timedOut)
            }
            let data = Data("[{\"sgv\":124}]".utf8)
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), data)
        }
        defer { NightscoutMockURLProtocol.handler = nil }

        let expectation = expectation(description: "v1 timeout fallback completed")
        _ = client.requestV3(
            path: "api/v3/entries",
            legacy: NightscoutLegacyEndpoint(path: "api/v1/entries.json", query: ["count": "1"])
        ) { result in
            if case .success(let response) = result {
                XCTAssertEqual(String(data: response.0, encoding: .utf8), "[{\"sgv\":124}]")
            } else {
                XCTFail("Expected a successful v1 fallback after a v3 timeout")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testV3OnlyDoesNotFallBackWhenCapabilityCheckTimesOut() throws {
        let restoreCredentials = useTemporaryCredentials(url: "https://v3-only-timeout.example.org", token: "")
        defer { restoreCredentials() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        var requestedPaths: [String] = []
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            requestedPaths.append(url.path)
            if url.path.hasSuffix("/api/v3/version") {
                throw URLError(.timedOut)
            }
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("[]".utf8))
        }
        defer { NightscoutMockURLProtocol.handler = nil }

        let expectation = expectation(description: "v3-only timeout completed")
        _ = client.requestV3(
            path: "api/v3/entries",
            legacy: NightscoutLegacyEndpoint(path: "api/v1/entries.json", query: ["count": "1"]),
            fallbackOnTransportFailure: false,
            allowLegacyFallback: false,
            readTimeout: 1
        ) { result in
            guard case .failure(let error as URLError) = result else {
                XCTFail("Expected the V3 timeout to be returned")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error.code, .timedOut)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2)
        XCTAssertEqual(requestedPaths, ["/api/v3/version"])
    }

    func testFallsBackToV1WhenV3EntriesRequestTimesOut() throws {
        let restoreCredentials = useTemporaryCredentials(url: "https://entries-timeout.example.org", token: "care-secret")
        defer { restoreCredentials() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        var requestedPaths: [String] = []
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            requestedPaths.append(url.path)
            if url.path == "/api/v3/version" {
                return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("{}".utf8))
            }
            if url.path == "/api/v2/authorization/request/token=care-secret" {
                return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("{\"token\":\"temporary-jwt\"}".utf8))
            }
            if url.path == "/api/v3/entries" {
                throw URLError(.timedOut)
            }
            XCTAssertEqual(url.path, "/api/v1/entries.json")
            XCTAssertNil(request.value(forHTTPHeaderField: "API-SECRET"))
            XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.filter { $0.name == "token" }.map(\.value), ["care-secret"])
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("[{\"sgv\":125}]".utf8))
        }
        defer { NightscoutMockURLProtocol.handler = nil }

        let expectation = expectation(description: "v1 entries fallback completed")
        _ = client.requestV3(
            path: "api/v3/entries",
            legacy: NightscoutLegacyEndpoint(path: "api/v1/entries.json", query: ["count": "1"]),
            fallbackOnTransportFailure: true
        ) { result in
            guard case .success(let response) = result else {
                XCTFail("Expected v1 fallback after the v3 entries timeout")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(String(data: response.0, encoding: .utf8), "[{\"sgv\":125}]")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(requestedPaths, [
            "/api/v3/version",
            "/api/v2/authorization/request/token=care-secret",
            "/api/v3/entries",
            "/api/v1/entries.json"
        ])
    }

    func testLegacyRequestUsesAccessTokenQueryParameter() throws {
        let restoreCredentials = useTemporaryCredentials(url: "https://cache.example.org/nightscout", token: "care-secret")
        defer { restoreCredentials() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(url.path, "/nightscout/api/v1/devicestatus.json")
            XCTAssertEqual(query["count"], "5")
            XCTAssertEqual(query["token"], "care-secret")
            XCTAssertNil(request.value(forHTTPHeaderField: "API-SECRET"))
            XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.filter { $0.name == "token" }.map(\.value), ["care-secret"])
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("[]".utf8))
        }
        defer { NightscoutMockURLProtocol.handler = nil }

        let expectation = expectation(description: "legacy device status request completed")
        _ = client.requestLegacy(
            path: "api/v1/devicestatus.json",
            query: ["count": "5"]
        ) { result in
            guard case .success = result else {
                XCTFail("Expected a successful legacy request")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testV3EntriesRequestUsesServerDefaultLimit() throws {
        let restoreCredentials = useTemporaryCredentials(url: "https://entries-v3.example.org/nightscout", token: "care-secret")
        defer { restoreCredentials() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        var entriesQuery: [String: String] = [:]
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path.hasSuffix("/api/v3/version") {
                return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("{}".utf8))
            }
            if url.path.hasSuffix("/api/v2/authorization/request/token=care-secret") {
                return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("{\"token\":\"temporary-jwt\"}".utf8))
            }
            XCTAssertEqual(url.path, "/nightscout/api/v3/entries")
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            entriesQuery = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertNil(entriesQuery["limit"])
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("[]".utf8))
        }
        defer { NightscoutMockURLProtocol.handler = nil }

        let expectation = expectation(description: "v3 entries request completed")
        _ = client.requestV3(
            path: "api/v3/entries",
            query: ["sort$desc": "date", "fields": "date,sgv"],
            legacy: NightscoutLegacyEndpoint(path: "api/v1/entries.json", query: ["count": "500"]),
            fallbackOnTransportFailure: false
        ) { result in
            guard case .success = result else {
                XCTFail("Expected a successful v3 entries request")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(entriesQuery["sort$desc"], "date")
        XCTAssertEqual(entriesQuery["fields"], "date,sgv")
    }

    func testV3ResponseEnvelopeIsUnwrapped() throws {
        let restoreCredentials = useTemporaryCredentials(url: "https://envelope.example.org", token: "")
        defer { restoreCredentials() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            let status: Int
            let data: Data
            if url.path.hasSuffix("/api/v3/version") {
                status = 200
                data = Data("{}".utf8)
            } else {
                status = 200
                data = Data("{\"status\":200,\"result\":[{\"sgv\":123}]}".utf8)
            }
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)), data)
        }
        defer { NightscoutMockURLProtocol.handler = nil }

        let expectation = expectation(description: "v3 envelope unwrapped")
        _ = client.requestV3(path: "api/v3/entries") { result in
            guard case .success(let response) = result else {
                XCTFail("Expected a successful v3 request")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(String(data: response.0, encoding: .utf8), "[{\"sgv\":123}]")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testDoesNotDowngradeAuthenticationFailureToV1() throws {
        let restoreCredentials = useTemporaryCredentials(url: "https://auth.example.org", token: "care-secret")
        defer { restoreCredentials() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        var requestedPaths: [String] = []
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            requestedPaths.append(url.path)
            let status: Int
            let data: Data
            if url.path == "/api/v3/version" {
                status = 200
                data = Data("{}".utf8)
            } else if url.path == "/api/v2/authorization/request/token=care-secret" {
                status = 200
                data = Data("{\"token\":\"temporary-jwt\"}".utf8)
            } else if url.path == "/api/v3/entries" {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer temporary-jwt")
                status = 401
                data = Data()
            } else {
                status = 500
                data = Data()
            }
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)), data)
        }
        defer { NightscoutMockURLProtocol.handler = nil }

        let expectation = expectation(description: "authentication error returned")
        _ = client.requestV3(
            path: "api/v3/entries",
            legacy: NightscoutLegacyEndpoint(path: "api/v1/entries.json", query: [:])
        ) { result in
            guard case .failure(let error as NightscoutHTTPError) = result else {
                XCTFail("Expected the v3 authentication error")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error.statusCode, 401)
            XCTAssertTrue(error.localizedDescription.contains("NS401-RETRY"))
            XCTAssertTrue(error.localizedDescription.contains(NightscoutJWTSource.fresh.message))
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(requestedPaths.filter { $0 == "/api/v2/authorization/request/token=care-secret" }.count, 2)
        XCTAssertEqual(requestedPaths.filter { $0 == "/api/v3/entries" }.count, 2)
        XCTAssertFalse(requestedPaths.contains("/api/v1/entries.json"))
    }

    func testLegacyWritesPreserveBodyAndEncodeTokenOnce() throws {
        let token = "care-secret&extra=value+#?"
        let restore = useTemporaryCredentials(url: "https://legacy-write.example.org/nightscout", token: token)
        defer { restore() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        let body = Data("{\"eventType\":\"Temporary Target\"}".utf8)
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            XCTAssertEqual(url.path, "/nightscout/api/v1/treatments")
            XCTAssertEqual(items.filter { $0.name == "token" }.map(\.value), [token])
            XCTAssertEqual(items.filter { $0.name == "count" }.map(\.value), ["1"])
            XCTAssertNil(request.value(forHTTPHeaderField: "API-SECRET"))
            XCTAssertEqual(request.httpMethod, "POST")
            // URLSession can convert the request body into a stream for URLProtocol.
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 1024)
                let count = stream.read(&bytes, maxLength: bytes.count)
                XCTAssertEqual(Data(bytes.prefix(max(0, count))), body)
            } else {
                XCTAssertEqual(request.httpBody, body)
            }
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("{}".utf8))
        }
        defer { NightscoutMockURLProtocol.handler = nil }
        let finished = expectation(description: "legacy write")
        _ = client.requestLegacy(path: "api/v1/treatments", query: ["count": "1"], method: "POST", body: body) { result in
            if case .failure(let error) = result { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func testLegacyRequestWithoutCredentialsOmitsToken() throws {
        let restore = useTemporaryCredentials(url: "https://legacy-public.example.org", token: "")
        defer { restore() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NightscoutMockURLProtocol.self]
        let client = NightscoutAPIClient(session: URLSession(configuration: configuration))
        NightscoutMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertFalse((URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).contains { $0.name == "token" })
            XCTAssertNil(request.value(forHTTPHeaderField: "API-SECRET"))
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("[]".utf8))
        }
        defer { NightscoutMockURLProtocol.handler = nil }
        let finished = expectation(description: "anonymous legacy read")
        _ = client.requestLegacy(path: "api/v1/entries.json", query: ["count": "1"]) { result in
            if case .failure(let error) = result { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    private func useTemporaryCredentials(url: String, token: String) -> () -> Void {
        let originalURL = UserDefaultsRepository.baseUri.value
        let temporaryURL = URL(string: url)!
        // These service tests use an ephemeral URLSession and must also run
        // on unsigned simulator builds, where Keychain access is not
        // guaranteed. Keeping the token in the legacy URL exercises the same
        // request construction without making the mock depend on Keychain.
        var temporaryURI = temporaryURL.absoluteString
        if !token.isEmpty {
            var tokenAllowed = CharacterSet.urlQueryAllowed
            tokenAllowed.remove(charactersIn: "&+#?")
            temporaryURI += "?token=\(token.addingPercentEncoding(withAllowedCharacters: tokenAllowed) ?? token)"
        }
        UserDefaultsRepository.baseUri.value = temporaryURI
        return {
            UserDefaultsRepository.baseUri.value = originalURL
        }
    }
    
    fileprivate var BASE_URI: String {
        
        let FALLBACKURL = "https://yournightscoutbackend.local"
        let bundle = Bundle(for: type(of: self))
        guard let filePath = bundle.path(forResource: ".env", ofType: nil) ?? Bundle.main.path(forResource: ".env", ofType: nil) else {
            print("Error: .env file not found in bundle")
            return FALLBACKURL // Fallback or empty? keeping original as default if missing to avoid breaking legacy setups without .env immediately
        }
        
        do {
            let contents = try String(contentsOfFile: filePath)
            let lines = contents.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1).map { String($0) }
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if key == "BASE_URI" {
                        return value
                    }
                }
            }
        } catch {
            print("Error reading .env file: \(error)")
        }
        
        return FALLBACKURL
    }
    
    func testReadYesterdaysChartDataShouldReturnData() {
        
        // Given
        let serviceBoundary = NightscoutService.singleton;
        UserDefaultsRepository.baseUri.value = BASE_URI
        let expectation = self.expectation(description: "Remote Call was successful!")
        
        // When
        serviceBoundary.readYesterdaysChartData({(bloodSugarArray: [BloodSugar]) -> Void in
            
            if bloodSugarArray.count > 0 {
                if TimeService.isYesterday(bloodSugarArray[0].timestamp) {
                    expectation.fulfill();
                }
            }
        })
        
        // Then
        self.waitForExpectations(timeout: 3.0, handler: nil)
    }
    
    func testReadStatus() {
        
        // Given
        let nightscoutService = NightscoutService.singleton;
        UserDefaultsRepository.baseUri.value = BASE_URI
        let expectation = self.expectation(description: "Remote Call was successful!")
        
        // When
        nightscoutService.readStatus({(units: Units) -> Void in
            
            if units == Units.mgdl {
                expectation.fulfill()
            }
        })
        
        // Then
        self.waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func testReadLast2HoursShouldReturnData() {
        
        // Given
        let serviceBoundary = NightscoutService.singleton;
        UserDefaultsRepository.baseUri.value = BASE_URI
        let expectation = self.expectation(description: "Remote Call was successful!")
        
        // When
        serviceBoundary.readLastTwoHoursChartData({(response) -> Void in
            
            switch response {
            
            case .data(let bloodSugarArray):
                if bloodSugarArray.count > 0 {
                    let twoHoursBefore = TimeService.getToday().addingTimeInterval(-60*120).timeIntervalSince1970
                    var allExpectationsFulFilled : Bool = true
                    for bloodSugar in bloodSugarArray {
                        if !(twoHoursBefore < bloodSugar.timestamp) {
                            allExpectationsFulFilled = false
                        }
                    }
                    
                    if allExpectationsFulFilled {
                        expectation.fulfill()
                    }
                }
            case .error(_):
                break
            }
        })
        
        // Then
        self.waitForExpectations(timeout: 5.0, handler: nil)
    }
}
