//
//  ServiceBoundaryTest.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 25.04.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation

import XCTest

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

class NightscoutServiceTest: XCTestCase {

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
        XCTAssertNil(query["token"])
    }

    func testV3URLConstructionRemovesLegacyTokenFromBaseURL() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://example.org/ns?token=secret&tenant=one"))
        let url = try XCTUnwrap(NightscoutAPIClient.shared.makeURL(baseURL: baseURL, path: "api/v3/status", query: [:]))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(query["tenant"], "one")
        XCTAssertNil(query["token"])
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

    func testCacheFriendlyLegacyRequestUsesAccessTokenHeader() throws {
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
            XCTAssertNil(query["token"])
            XCTAssertEqual(request.value(forHTTPHeaderField: "API-SECRET"), "care-secret")
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data("[]".utf8))
        }
        defer { NightscoutMockURLProtocol.handler = nil }

        let expectation = expectation(description: "cache-friendly device status request completed")
        _ = client.requestLegacy(
            path: "api/v1/devicestatus.json",
            query: ["count": "5"],
            useAccessTokenHeader: true
        ) { result in
            guard case .success = result else {
                XCTFail("Expected a successful cache-friendly legacy request")
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
            fallbackOnTransportFailure: false,
            legacyUseAccessTokenHeader: true
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
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(requestedPaths.filter { $0 == "/api/v2/authorization/request/token=care-secret" }.count, 2)
        XCTAssertEqual(requestedPaths.filter { $0 == "/api/v3/entries" }.count, 2)
        XCTAssertFalse(requestedPaths.contains("/api/v1/entries.json"))
    }

    private func useTemporaryCredentials(url: String, token: String) -> () -> Void {
        let originalURL = UserDefaultsRepository.baseUri.value
        let originalToken = UserDefaultsRepository.nightscoutToken
        let temporaryURL = URL(string: url)!
        XCTAssertTrue(UserDefaultsRepository.setNightscoutCredentials(baseURL: temporaryURL, token: token))
        return {
            _ = NightscoutCredentialStore.shared.removeToken(for: temporaryURL)
            if let url = URL(string: originalURL), !originalURL.isEmpty {
                _ = UserDefaultsRepository.setNightscoutCredentials(baseURL: url, token: originalToken)
            } else {
                UserDefaultsRepository.baseUri.value = ""
            }
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
