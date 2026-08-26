//
//  ServiceBoundary.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 26.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation

protocol NightscoutTask: AnyObject {
    var nightscoutIsRunning: Bool { get }
    func cancel()
}

extension URLSessionTask: NightscoutTask {
    var nightscoutIsRunning: Bool { state == .running }
}

final class NightscoutRequestTask: NightscoutTask {
    private let lock = NSLock()
    private var tasks: [NightscoutTask] = []
    private var running = true
    private var cancelled = false

    var nightscoutIsRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running && !cancelled
    }

    func add(_ task: NightscoutTask) {
        lock.lock()
        let shouldCancel = cancelled
        if !shouldCancel { tasks.append(task) }
        lock.unlock()
        if shouldCancel { task.cancel() }
    }

    func finish() {
        lock.lock()
        running = false
        tasks.removeAll()
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        running = false
        let tasksToCancel = tasks
        tasks.removeAll()
        lock.unlock()
        tasksToCancel.forEach { $0.cancel() }
    }
}

struct NightscoutLegacyEndpoint {
    let path: String
    let query: [String: String]
}

struct NightscoutHTTPError: LocalizedError {
    let statusCode: Int
    let endpoint: String

    var errorDescription: String? {
        switch statusCode {
        case 401:
            return NSLocalizedString("The Nightscout token is invalid or has expired.", comment: "Nightscout HTTP 401")
        case 403:
            return NSLocalizedString("The Nightscout token does not have permission for this operation.", comment: "Nightscout HTTP 403")
        default:
            return String(format: NSLocalizedString("Nightscout returned HTTP %d for %@.", comment: "Nightscout HTTP error"), statusCode, endpoint)
        }
    }
}

final class NightscoutAPIClient {
    static let shared = NightscoutAPIClient()

    private enum V3Support { case supported, unsupported }
    private let defaultRequestTimeout: TimeInterval = 20
    // A watchOS widget extension often has to wake its radio before the
    // request can start. Eight seconds proved too aggressive for that path
    // and made otherwise healthy v3 servers look unavailable in background.
    private let v3ReadTimeout: TimeInterval = 20
    private let session: URLSession
    private let lock = NSLock()
    private var supportByServer: [String: V3Support] = [:]
    private var jwtByCredential: [String: String] = [:]
    private var pendingJWT: [String: [(Result<String, Error>) -> Void]] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    @discardableResult
    func requestV3(
        path: String,
        query: [String: String] = [:],
        method: String = "GET",
        body: Data? = nil,
        legacy: NightscoutLegacyEndpoint? = nil,
        fallbackOnTransportFailure: Bool = true,
        legacyUseAccessTokenHeader: Bool = false,
        completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void
    ) -> NightscoutTask? {
        guard let baseURL = UserDefaultsRepository.cleanBaseURL() else {
            logError("Nightscout request rejected: base URL is empty or invalid")
            completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)))
            return nil
        }

        let trackedTask = NightscoutRequestTask()
        determineV3Support(
            baseURL: baseURL,
            trackedTask: trackedTask,
            allowTransportFallback: method.uppercased() == "GET" && fallbackOnTransportFailure
        ) { result in
            switch result {
            case .failure(let error):
                trackedTask.finish()
                completion(.failure(error))
            case .success(false):
                self.performLegacy(
                    legacy,
                    method: method,
                    body: body,
                    trackedTask: trackedTask,
                    compatibilityFallback: true,
                    useAccessTokenHeader: legacyUseAccessTokenHeader,
                    completion: completion
                )
            case .success(true):
                self.performAuthorizedV3(
                    baseURL: baseURL,
                    path: path,
                    query: query,
                    method: method,
                    body: body,
                    legacy: legacy,
                    trackedTask: trackedTask,
                    mayRefreshJWT: true,
                    fallbackOnTransportFailure: fallbackOnTransportFailure,
                    legacyUseAccessTokenHeader: legacyUseAccessTokenHeader,
                    completion: completion
                )
            }
        }
        return trackedTask
    }

    @discardableResult
    func requestLegacy(
        path: String,
        query: [String: String] = [:],
        method: String = "GET",
        body: Data? = nil,
        useAccessTokenHeader: Bool = false,
        completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void
    ) -> NightscoutTask? {
        let trackedTask = NightscoutRequestTask()
        performLegacy(
            NightscoutLegacyEndpoint(path: path, query: query),
            method: method,
            body: body,
            trackedTask: trackedTask,
            useAccessTokenHeader: useAccessTokenHeader,
            completion: completion
        )
        return trackedTask
    }

    private func determineV3Support(
        baseURL: URL,
        trackedTask: NightscoutRequestTask,
        allowTransportFallback: Bool,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        let key = baseURL.absoluteString
        lock.lock()
        let cached = supportByServer[key]
        lock.unlock()
        if let cached = cached {
            completion(.success(cached == .supported))
            return
        }

        guard let url = makeURL(baseURL: baseURL, path: "api/v3/version", query: [:]) else {
            logError("Nightscout v3 capability check rejected: invalid server URL")
            completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)))
            return
        }
        let task = session.dataTask(with: request(url: url, method: "GET", body: nil, timeoutInterval: v3ReadTimeout)) { _, response, error in
            if let error = error {
                if allowTransportFallback && self.isTransportFailure(error) {
                    self.logWarning("Nightscout v3 capability check failed (\(self.errorSummary(error))); trying v1 compatibility mode")
                    completion(.success(false))
                } else {
                    self.logError("Nightscout v3 capability check failed: \(self.errorSummary(error))")
                    completion(.failure(error))
                }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                self.logError("Nightscout v3 capability check failed: invalid server response")
                completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)))
                return
            }
            if http.statusCode == 404 || http.statusCode == 405 {
                self.setSupport(.unsupported, for: key)
                self.logInfo("Nightscout v3 is unavailable (HTTP \(http.statusCode)); using v1 compatibility mode")
                completion(.success(false))
            } else if (200..<300).contains(http.statusCode) {
                self.setSupport(.supported, for: key)
                completion(.success(true))
            } else {
                self.logError("Nightscout v3 capability check returned HTTP \(http.statusCode)")
                completion(.failure(NightscoutHTTPError(statusCode: http.statusCode, endpoint: "/api/v3/version")))
            }
        }
        trackedTask.add(task)
        task.resume()
    }

    private func performAuthorizedV3(
        baseURL: URL,
        path: String,
        query: [String: String],
        method: String,
        body: Data?,
        legacy: NightscoutLegacyEndpoint?,
        trackedTask: NightscoutRequestTask,
        mayRefreshJWT: Bool,
        fallbackOnTransportFailure: Bool,
        legacyUseAccessTokenHeader: Bool,
        completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void
    ) {
        let accessToken = UserDefaultsRepository.nightscoutToken
        if accessToken.isEmpty {
            performV3Request(baseURL: baseURL, path: path, query: query, method: method, body: body, jwt: nil, trackedTask: trackedTask) { result in
                if self.shouldFallbackToLegacy(result: result, method: method, legacy: legacy, allowUnauthorized: fallbackOnTransportFailure, allowTransportFailure: fallbackOnTransportFailure) {
                    self.logWarning("Nightscout v3 read returned HTTP 401 without a JWT; using v1 compatibility mode")
                    self.performLegacy(
                        legacy,
                        method: method,
                        body: body,
                        trackedTask: trackedTask,
                        compatibilityFallback: true,
                        useAccessTokenHeader: legacyUseAccessTokenHeader,
                        completion: completion
                    )
                } else {
                    trackedTask.finish()
                    completion(result)
                }
            }
            return
        }

        obtainJWT(baseURL: baseURL, accessToken: accessToken, trackedTask: trackedTask) { jwtResult in
            switch jwtResult {
            case .failure(let error):
                trackedTask.finish()
                completion(.failure(error))
            case .success(let jwt):
                self.performV3Request(baseURL: baseURL, path: path, query: query, method: method, body: body, jwt: jwt, trackedTask: trackedTask) { result in
                    if case .failure(let error as NightscoutHTTPError) = result,
                       error.statusCode == 401, mayRefreshJWT {
                        self.invalidateJWT(baseURL: baseURL, accessToken: accessToken)
                        self.performAuthorizedV3(baseURL: baseURL, path: path, query: query, method: method, body: body, legacy: legacy, trackedTask: trackedTask, mayRefreshJWT: false, fallbackOnTransportFailure: fallbackOnTransportFailure, legacyUseAccessTokenHeader: legacyUseAccessTokenHeader, completion: completion)
                    } else if self.shouldFallbackToLegacy(result: result, method: method, legacy: legacy, allowUnauthorized: false, allowTransportFailure: fallbackOnTransportFailure) {
                        self.logWarning("Nightscout v3 GET failed (\(self.resultErrorSummary(result))); using v1 compatibility mode")
                        self.performLegacy(
                            legacy,
                            method: method,
                            body: body,
                            trackedTask: trackedTask,
                            compatibilityFallback: true,
                            useAccessTokenHeader: legacyUseAccessTokenHeader,
                            completion: completion
                        )
                    } else {
                        trackedTask.finish()
                        completion(result)
                    }
                }
            }
        }
    }

    private func performV3Request(baseURL: URL, path: String, query: [String: String], method: String, body: Data?, jwt: String?, trackedTask: NightscoutRequestTask, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        let endpoint = safeEndpoint(path: path, query: query)
        guard let url = makeURL(baseURL: baseURL, path: path, query: query) else {
            logError("Nightscout v3 request rejected: invalid endpoint \(endpoint)")
            completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)))
            return
        }
        let timeout = method.uppercased() == "GET" ? v3ReadTimeout : defaultRequestTimeout
        var urlRequest = request(url: url, method: method, body: body, timeoutInterval: timeout)
        if let jwt = jwt { urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization") }
        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                self.logError("Nightscout v3 request \(endpoint) failed (timeout \(Int(timeout))s): \(self.errorSummary(error))")
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                self.logError("Nightscout v3 request \(endpoint) failed: invalid server response")
                completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)))
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                self.logError("Nightscout v3 request \(endpoint) returned HTTP \(http.statusCode)")
                completion(.failure(NightscoutHTTPError(statusCode: http.statusCode, endpoint: "/\(path)")))
                return
            }
            completion(.success((self.v3PayloadData(from: data ?? Data()), http)))
        }
        trackedTask.add(task)
        task.resume()
    }

    private func performLegacy(_ endpoint: NightscoutLegacyEndpoint?, method: String, body: Data?, trackedTask: NightscoutRequestTask, compatibilityFallback: Bool = false, useAccessTokenHeader: Bool = false, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        guard let endpoint = endpoint,
              let url = legacyURL(endpoint, useAccessTokenHeader: useAccessTokenHeader) else {
            logError("Nightscout legacy request rejected: invalid endpoint")
            trackedTask.finish()
            completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnsupportedURL)))
            return
        }
        let endpointDescription = safeEndpoint(path: endpoint.path, query: endpoint.query)
        if compatibilityFallback {
            logInfo("Nightscout v1 compatibility request started \(endpointDescription)")
        }
        var urlRequest = request(url: url, method: method, body: body)
        if useAccessTokenHeader {
            let accessToken = UserDefaultsRepository.nightscoutToken
            if !accessToken.isEmpty {
                // cgm-remote-monitor accepts an access token in API-SECRET.
                // Keeping it out of the query leaves `count` as the only
                // query parameter, which enables the server-side cache path.
                urlRequest.setValue(accessToken, forHTTPHeaderField: "API-SECRET")
            }
        }
        let task = session.dataTask(with: urlRequest) { data, response, error in
            defer { trackedTask.finish() }
            if let error = error {
                self.logError("Nightscout v1 request \(endpointDescription) failed: \(self.errorSummary(error))")
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                self.logError("Nightscout v1 request \(endpointDescription) failed: invalid server response")
                completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)))
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                self.logError("Nightscout v1 request \(endpointDescription) returned HTTP \(http.statusCode)")
                completion(.failure(NightscoutHTTPError(statusCode: http.statusCode, endpoint: "/\(endpoint.path)")))
                return
            }
            if compatibilityFallback {
                self.logInfo("Nightscout v1 compatibility request succeeded \(endpointDescription) (HTTP \(http.statusCode))")
            }
            completion(.success((data ?? Data(), http)))
        }
        trackedTask.add(task)
        task.resume()
    }

    private func legacyURL(_ endpoint: NightscoutLegacyEndpoint, useAccessTokenHeader: Bool) -> URL? {
        if useAccessTokenHeader,
           let baseURL = UserDefaultsRepository.cleanBaseURL() {
            return makeURL(baseURL: baseURL, path: endpoint.path, query: endpoint.query)
        }
        return UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: endpoint.path, queryParams: endpoint.query)
    }

    private func v3PayloadData(from data: Data) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let envelope = json as? [String: Any],
              let result = envelope["result"],
              JSONSerialization.isValidJSONObject(result),
              let payload = try? JSONSerialization.data(withJSONObject: result) else {
            return data
        }
        return payload
    }

    private func obtainJWT(baseURL: URL, accessToken: String, trackedTask: NightscoutRequestTask, completion: @escaping (Result<String, Error>) -> Void) {
        let key = credentialKey(baseURL: baseURL, accessToken: accessToken)
        lock.lock()
        if let jwt = jwtByCredential[key] {
            lock.unlock()
            completion(.success(jwt))
            return
        }
        if pendingJWT[key] != nil {
            pendingJWT[key]?.append(completion)
            lock.unlock()
            return
        }
        pendingJWT[key] = [completion]
        lock.unlock()

        guard let url = makeURL(baseURL: baseURL, path: "api/v2/authorization/request/token=\(accessToken)", query: [:]) else {
            logError("Nightscout JWT request rejected: invalid server URL")
            completeJWT(key: key, result: .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)))
            return
        }
        let task = session.dataTask(with: request(url: url, method: "GET", body: nil)) { data, response, error in
            if let error = error {
                self.logError("Nightscout JWT exchange failed: \(self.errorSummary(error))")
                self.completeJWT(key: key, result: .failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                self.logError("Nightscout JWT exchange failed: invalid server response")
                self.completeJWT(key: key, result: .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)))
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                self.logError("Nightscout JWT exchange returned HTTP \(http.statusCode)")
                self.completeJWT(key: key, result: .failure(NightscoutHTTPError(statusCode: http.statusCode, endpoint: "/api/v2/authorization/request")))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let jwt = json["token"] as? String, !jwt.isEmpty else {
                self.logError("Nightscout JWT exchange returned an invalid response")
                self.completeJWT(key: key, result: .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotParseResponse)))
                return
            }
            self.lock.lock()
            self.jwtByCredential[key] = jwt
            self.lock.unlock()
            self.completeJWT(key: key, result: .success(jwt))
        }
        trackedTask.add(task)
        task.resume()
    }

    private func completeJWT(key: String, result: Result<String, Error>) {
        lock.lock()
        let completions = pendingJWT.removeValue(forKey: key) ?? []
        lock.unlock()
        completions.forEach { $0(result) }
    }

    private func invalidateJWT(baseURL: URL, accessToken: String) {
        lock.lock()
        jwtByCredential.removeValue(forKey: credentialKey(baseURL: baseURL, accessToken: accessToken))
        lock.unlock()
    }

    private func setSupport(_ support: V3Support, for key: String) {
        lock.lock()
        supportByServer[key] = support
        lock.unlock()
    }

    private func logInfo(_ message: String) {
        AppLogger.singleton.info(message, category: .nightscout)
    }

    private func logWarning(_ message: String) {
        AppLogger.singleton.warning(message, category: .nightscout)
    }

    private func logError(_ message: String) {
        AppLogger.singleton.error(message, category: .nightscout)
    }

    private func resultErrorSummary(_ result: Result<(Data, HTTPURLResponse), Error>) -> String {
        guard case .failure(let error) = result else { return "unknown error" }
        return errorSummary(error)
    }

    private func errorSummary(_ error: Error) -> String {
        if let httpError = error as? NightscoutHTTPError {
            return "HTTP \(httpError.statusCode)"
        }
        if let urlError = error as? URLError {
            return "URLSession \(urlError.code.rawValue): \(urlError.localizedDescription)"
        }
        return error.localizedDescription
    }

    private func safePath(_ path: String) -> String {
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let authPrefix = "/api/v2/authorization/request/"
        if let range = normalizedPath.range(of: authPrefix) {
            return String(normalizedPath[..<range.upperBound]) + "<redacted>"
        }
        return normalizedPath
    }

    /// Returns a log-safe, deterministic endpoint representation. The access
    /// token is never part of v3 query parameters (it is sent as a Bearer
    /// header), but keep this formatter independent of the base URL anyway so
    /// credentials cannot accidentally enter the AppLog.
    private func safeEndpoint(path: String, query: [String: String]) -> String {
        let normalizedPath = safePath(path)
        guard !query.isEmpty else { return normalizedPath }

        var components = URLComponents()
        components.queryItems = query
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let encodedQuery = components.percentEncodedQuery, !encodedQuery.isEmpty else {
            return normalizedPath
        }
        return "\(normalizedPath)?\(encodedQuery)"
    }

    private func shouldFallbackToLegacy(
        result: Result<(Data, HTTPURLResponse), Error>,
        method: String,
        legacy: NightscoutLegacyEndpoint?,
        allowUnauthorized: Bool,
        allowTransportFailure: Bool
    ) -> Bool {
        guard method.uppercased() == "GET", legacy != nil else { return false }
        guard case .failure(let error) = result else { return false }
        if let httpError = error as? NightscoutHTTPError {
            if httpError.statusCode == 404 || httpError.statusCode == 405 {
                return true
            }
            return allowUnauthorized && httpError.statusCode == 401
        }
        return allowTransportFailure && isTransportFailure(error)
    }

    private func isTransportFailure(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost,
             .networkConnectionLost, .notConnectedToInternet, .secureConnectionFailed:
            return true
        default:
            return false
        }
    }

    private func credentialKey(baseURL: URL, accessToken: String) -> String {
        baseURL.absoluteString + "\n" + accessToken
    }

    func makeURL(baseURL: URL, path: String, query: [String: String]) -> URL? {
        var url = baseURL
        path.split(separator: "/").forEach { url.appendPathComponent(String($0), isDirectory: false) }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var items = (components.queryItems ?? []).filter { $0.name != "token" }
        items.append(contentsOf: query.sorted(by: { $0.key < $1.key }).map { URLQueryItem(name: $0.key, value: $0.value) })
        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }

    private func request(url: URL, method: String, body: Data?, timeoutInterval: TimeInterval? = nil) -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeoutInterval ?? defaultRequestTimeout
        )
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        request.httpBody = body
        return request
    }
}

/* Generic Nightscout request result */
enum NightscoutRequestResult<T> {
    case data(T)
    case error(Error)
}

final class HybridEntriesAccumulator {
    private let lock = NSLock()
    private var receivedSources: [String] = []
    private var successfulRecords: [(source: String, records: [NightscoutEntryRecord])] = []
    private var errors: [Error] = []
    private var completed = false
    private let completion: (NightscoutRequestResult<[NightscoutEntryRecord]>, String) -> Void

    init(completion: @escaping (NightscoutRequestResult<[NightscoutEntryRecord]>, String) -> Void) {
        self.completion = completion
    }

    func receive(_ result: NightscoutRequestResult<[NightscoutEntryRecord]>, source: String) {
        var resolvedResult: NightscoutRequestResult<[NightscoutEntryRecord]>?
        var sourceSummary = source

        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }

        receivedSources.append(source)
        switch result {
        case .data(let records):
            successfulRecords.append((source, records))
        case .error(let error):
            errors.append(error)
        }

        if resolvedResult == nil, receivedSources.count >= 2 {
            completed = true
            if successfulRecords.isEmpty {
                resolvedResult = .error(errors.last ?? NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
            } else {
                resolvedResult = .data(merged(successfulRecords.flatMap(\.records)))
                sourceSummary = successfulRecords.map(\.source).joined(separator: "+")
            }
        }
        lock.unlock()

        if let resolvedResult {
            completion(resolvedResult, sourceSummary)
        }
    }

    func finishAvailable(reason: String) {
        var resolvedResult: NightscoutRequestResult<[NightscoutEntryRecord]>?
        var sourceSummary = reason

        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        if successfulRecords.isEmpty {
            resolvedResult = .error(errors.last ?? URLError(.timedOut))
        } else {
            resolvedResult = .data(merged(successfulRecords.flatMap(\.records)))
            sourceSummary = successfulRecords.map(\.source).joined(separator: "+") + "+" + reason
        }
        lock.unlock()

        if let resolvedResult {
            completion(resolvedResult, sourceSummary)
        }
    }

    private func merged(_ records: [NightscoutEntryRecord]) -> [NightscoutEntryRecord] {
        var recordsByKey: [String: NightscoutEntryRecord] = [:]
        records.forEach { record in
            if let existing = recordsByKey[record.storageKey] {
                recordsByKey[record.storageKey] = record.dateMillis >= existing.dateMillis ? record : existing
            } else {
                recordsByKey[record.storageKey] = record
            }
        }
        return recordsByKey.values.sorted { $0.dateMillis < $1.dateMillis }
    }
}

/* All data that is read from nightscout is accessed using this boundary. */
class NightscoutService {
    
    static let singleton = NightscoutService()
    
    let ONE_DAY_IN_MICROSECONDS = Double(60*60*24*1000)
    let DIRECTIONS = ["-", "↑↑", "↑", "↗", "→", "↘︎", "↓", "↓↓", "-", "-"]
    
    enum EventType : String {
        case sensorStart = "Sensor Change"
        case pumpBatteryChange = "Pump Battery Change"
        case cannulaChange = "Site Change"
        case temporaryTarget = "Temporary Target"
    }
    
    /* Reads the last 20 historic blood glucose data from the nightscout server. */
    @discardableResult
    func readChartData(_ resultHandler : @escaping (NightscoutRequestResult<[Int]>) -> Void) -> NightscoutTask? {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }

        // Keep this compatibility helper v3-first as well. Normal UI code
        // uses the shared entries stream, but older callers must not make v1
        // the primary API path.
        AppLogger.singleton.debug(
            "NightscoutService: requesting chart preview through the v3 entries collection",
            category: .nightscout
        )
        return NightscoutAPIClient.shared.requestV3(
            path: "api/v3/entries",
            query: [
                "limit": "20",
                "sort$desc": "date",
                "fields": "date,sgv"
            ],
            legacy: NightscoutLegacyEndpoint(path: "api/v1/entries.json", query: ["count": "20"]),
            fallbackOnTransportFailure: true,
            legacyUseAccessTokenHeader: true
        ) { result in
            switch result {
            case .failure(let error):
                dispatchOnMain { resultHandler(.error(error)) }
            case .success(let response):
                guard let entries = try? JSONSerialization.jsonObject(with: response.0) as? [[String: Any]] else {
                    self.logServiceError("Entries response could not be decoded")
                    dispatchOnMain { resultHandler(.error(self.createNoDataError(description: NSLocalizedString("Invalid entries response from Nightscout.", comment: "Invalid entries response")))) }
                    return
                }
                let values = entries.compactMap { self.doubleValue($0["sgv"]).map(Int.init) }.reversed()
                dispatchOnMain { resultHandler(.data(Array(values))) }
            }
        }
    }
    
    func readChartData(_ resultHandler : @escaping ([Int]) -> Void) {
        self.readChartData { (result: NightscoutRequestResult<[Int]>)  in
            if case .data(let data) = result {
                resultHandler(data)
            }
        }
    }

    /// Reads the newest entries through the generic v3 collection. The server
    /// applies its configured API3_MAX_LIMIT when no explicit limit is sent;
    /// the returned records are deliberately raw enough for all consumers
    /// (current value, charts and manual meter values) to derive their own
    /// views from one synchronized snapshot.
    @discardableResult
    func readEntriesHead(
        resultHandler: @escaping (NightscoutRequestResult<[NightscoutEntryRecord]>) -> Void
    ) -> NightscoutTask? {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }

        let trackedTask = NightscoutRequestTask()
        let startedAt = Date()
        let streamCutoffMillis = (Date().timeIntervalSince1970 - (48 * 60 * 60)) * 1000
        AppLogger.singleton.debug(
            "NightscoutService: requesting entries stream through v3 with 48-hour cutoff",
            category: .nightscout
        )

        let finish: (NightscoutRequestResult<[NightscoutEntryRecord]>) -> Void = { result in
            trackedTask.finish()
            dispatchOnMain { resultHandler(result) }
        }

        let parseResponse: (Data, String) -> Void = { data, source in
            do {
                let records = try self.parseEntryRecords(from: data)
                let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000)
                AppLogger.singleton.info(
                    "NightscoutService: entries stream head succeeded source=\(source) count=\(records.count) duration=\(elapsed)ms",
                    category: .nightscout
                )
                finish(.data(records))
            } catch {
                self.logServiceError("Entries stream response could not be decoded: \(error.localizedDescription)")
                finish(.error(error))
            }
        }

        let v3Task = NightscoutAPIClient.shared.requestV3(
            path: "api/v3/entries",
            query: [
                "date$gte": "\(streamCutoffMillis)",
                "sort$desc": "date",
                "type$in": "sgv|mbg",
                "limit": "500",
                "fields": "identifier,_id,date,mills,type,sgv,mbg,direction,units"
            ],
            legacy: NightscoutLegacyEndpoint(
                path: "api/v1/entries.json",
                query: ["count": "500"]
            ),
            fallbackOnTransportFailure: true,
            legacyUseAccessTokenHeader: true
        ) { result in
            switch result {
            case .success(let response):
                // requestV3 transparently uses the configured v1 endpoint
                // when v3 is unavailable or a transient transport failure
                // occurs. The API client logs that transition explicitly.
                parseResponse(response.0, "v3-or-v1-compatibility")
            case .failure(let error):
                AppLogger.singleton.error(
                    "NightscoutService: entries stream failed after v3/compatibility handling: \(error.localizedDescription)",
                    category: .nightscout
                )
                finish(.error(error))
            }
        }
        if let v3Task { trackedTask.add(v3Task) }
        return trackedTask
    }

    /// Reads only the entries needed for the current display. Both APIs are
    /// started together because the v1 entries cache is substantially faster
    /// on some Nightscout installations while v3 remains the preferred modern
    /// source. A fresh response can complete the request immediately; stale
    /// responses are held until the other API has had a chance to provide a
    /// newer value.
    @discardableResult
    func readLatestEntriesHybrid(
        limit: Int = 20,
        apiClient: NightscoutAPIClient = .shared,
        resultHandler: @escaping (NightscoutRequestResult<[NightscoutEntryRecord]>) -> Void
    ) -> NightscoutTask? {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }

        let trackedTask = NightscoutRequestTask()
        let accumulator = HybridEntriesAccumulator { result, sourceSummary in
            trackedTask.finish()
            AppLogger.singleton.info(
                "NightscoutService: hybrid display entries completed source=\(sourceSummary)",
                category: .nightscout
            )
            dispatchOnMain { resultHandler(result) }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 8) {
            accumulator.finishAvailable(reason: "deadline")
        }

        func parsedResult(_ result: Result<(Data, HTTPURLResponse), Error>) -> NightscoutRequestResult<[NightscoutEntryRecord]> {
            switch result {
            case .failure(let error):
                return .error(error)
            case .success(let response):
                do {
                    return .data(try self.parseEntryRecords(from: response.0))
                } catch {
                    return .error(error)
                }
            }
        }

        let requestedLimit = max(2, min(limit, 100))
        if let task = apiClient.requestV3(
            path: "api/v3/entries",
            query: [
                "sort$desc": "date",
                "type$in": "sgv|mbg",
                "limit": "\(requestedLimit)",
                "fields": "identifier,_id,date,mills,type,sgv,mbg,direction,units"
            ],
            fallbackOnTransportFailure: false,
            completion: { result in
                accumulator.receive(parsedResult(result), source: "v3")
            }
        ) {
            trackedTask.add(task)
        }

        if let task = apiClient.requestLegacy(
            path: "api/v1/entries.json",
            query: ["count": "\(requestedLimit)"],
            useAccessTokenHeader: true,
            completion: { result in
                accumulator.receive(parsedResult(result), source: "v1")
            }
        ) {
            trackedTask.add(task)
        }

        return trackedTask
    }

    func parseEntryRecords(from data: Data) throws -> [NightscoutEntryRecord] {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let entries = json as? [[String: Any]] else {
            throw createNoDataError(description: NSLocalizedString("Invalid entries response from Nightscout.", comment: "Invalid entries response"))
        }

        return entries.compactMap { entry in
            guard let dateMillis = timestampMillis(entry["date"] ?? entry["mills"]) else { return nil }

            let sgv = doubleValue(entry["sgv"])
            let mbg = doubleValue(entry["mbg"])
            let explicitType = (entry["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let type = explicitType.flatMap { $0.isEmpty ? nil : $0 }
                ?? (sgv != nil ? "sgv" : (mbg != nil ? "mbg" : "unknown"))
            guard sgv != nil || mbg != nil || type != "unknown" else { return nil }

            let identifier = stringValue(entry["identifier"])
            let objectID = stringValue(entry["_id"])
            let rawJSON = try? JSONSerialization.data(withJSONObject: entry, options: [])
            return NightscoutEntryRecord(
                identifier: identifier,
                objectID: objectID,
                dateMillis: dateMillis,
                type: type,
                sgv: sgv,
                mbg: mbg,
                direction: stringValue(entry["direction"]),
                units: stringValue(entry["units"]),
                rawJSON: rawJSON
            )
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        if let value = value as? String, !value.isEmpty { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }
    
    /* Reads the nightscout status from the backend. This is used to determine the configured
     Unit, whether it's mg/dL or mmol/l */
    @discardableResult
    func readStatus(_ resultHandler : @escaping (NightscoutRequestResult<Units>) -> Void) -> NightscoutTask? {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }

        // Units are exposed by the lightweight status endpoint. This remains a
        // separate compatibility endpoint and is not part of the Entries
        // collection stream.
        AppLogger.singleton.debug(
            "NightscoutService: requesting glucose units through the cache-friendly v1 status endpoint",
            category: .nightscout
        )
        return readLegacyStatus(resultHandler)
    }

    @discardableResult
    private func readLegacyStatus(_ resultHandler: @escaping (NightscoutRequestResult<Units>) -> Void) -> NightscoutTask? {
        return NightscoutAPIClient.shared.requestLegacy(
            path: "api/v1/status.json",
            useAccessTokenHeader: true
        ) { result in
            switch result {
            case .failure(let error):
                dispatchOnMain { resultHandler(.error(error)) }
            case .success(let response):
                do {
                    guard let units = try self.units(from: response.0) else {
                        throw self.createNoDataError(description: NSLocalizedString("Nightscout did not return configured glucose units.", comment: "Missing Nightscout units"))
                    }
                    dispatchOnMain { resultHandler(.data(units)) }
                } catch {
                    self.logServiceError("Entries history response could not be decoded: \(error.localizedDescription)")
                    dispatchOnMain { resultHandler(.error(error)) }
                }
            }
        }
    }

    private func units(from data: Data) throws -> Units? {
        let json = try JSONSerialization.jsonObject(with: data)
        let unitsString: String?
        if let entries = json as? [[String: Any]] {
            unitsString = entries.first?["units"] as? String
        } else if let status = json as? [String: Any], let settings = status["settings"] as? [String: Any] {
            unitsString = settings["units"] as? String
        } else {
            throw createNoDataError(description: NSLocalizedString("Invalid status response from Nightscout.", comment: "Invalid Nightscout status"))
        }
        guard let unitsString = unitsString else { return nil }
        return unitsString.lowercased().contains("mg") ? .mgdl : .mmol
    }
    
    func readStatus(_ resultHandler : @escaping (Units) -> Void) {
        self.readStatus { (result: NightscoutRequestResult<Units>)  in
            if case .data(let data) = result {
                resultHandler(data)
            }
        }
    }
    
    /* Reads all data between two timestamps and limits the maximum return values to 1440. */
    fileprivate func directionToArrow(_ bloodValueArrow: String) -> String {
        
        switch bloodValueArrow {
        case "DoubleUp":
            return "↑↑"
        case "SingleUp":
            return "↑"
        case "FortyFiveUp":
            return "↗"
        case "Flat":
            return "→"
        case "FortyFiveDown":
            return "↘"
        case "SingleDown":
            return "↓"
        case "DoubleDown":
            return "↓↓"
        default:
            return "-"
        }
    }
    
    @discardableResult
    func readChartDataWithinPeriodOfTime(oldValues : [BloodSugar], _ timestamp1 : Date, timestamp2 : Date, resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>) -> Void) -> NightscoutTask? {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }

        let from = timestamp1.timeIntervalSince1970 * 1000
        let to = timestamp2.timeIntervalSince1970 * 1000
        let legacyQuery = [
            "find[date][$gt]": "\(from)",
            "find[date][$lte]": "\(to)",
            "count": "1440"
        ]
        let v3Query = [
            "date$gt": "\(from)",
            "date$lte": "\(to)",
            "type$in": "sgv|mbg",
            "sort": "date",
            "limit": "500",
            "fields": "identifier,_id,date,type,sgv,mbg,direction"
        ]

        return NightscoutAPIClient.shared.requestV3(
            path: "api/v3/entries",
            query: v3Query,
            legacy: NightscoutLegacyEndpoint(path: "api/v1/entries.json", query: legacyQuery),
            fallbackOnTransportFailure: true,
            legacyUseAccessTokenHeader: true
        ) { result in
            switch result {
            case .failure(let error):
                dispatchOnMain { resultHandler(.error(error)) }
            case .success(let response):
                do {
                    guard let entries = try JSONSerialization.jsonObject(with: response.0) as? [[String: Any]] else {
                        throw NSError(domain: "EntriesJSONError", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid JSON received from the Nightscout entries API.", comment: "Invalid entries JSON")])
                    }
                    let entriesInRange = entries.filter { entry in
                        guard let timestamp = self.timestampMillis(entry["date"]) else { return false }
                        return timestamp > from && timestamp <= to
                    }
                    if entriesInRange.count != entries.count {
                        AppLogger.singleton.debug(
                            "NightscoutService: filtered \(entries.count - entriesInRange.count) glucose entry/entries outside the requested time range",
                            category: .nightscout
                        )
                    }
                    if !entries.isEmpty && entriesInRange.isEmpty {
                        AppLogger.singleton.warning(
                            "NightscoutService: all returned glucose entries were outside the requested time range (from=\(from), to=\(to))",
                            category: .nightscout
                        )
                    }

                    let parsed = entriesInRange.compactMap { entry -> BloodSugar? in
                        guard let timestamp = self.timestampMillis(entry["date"]) else { return nil }
                        if let sgv = self.doubleValue(entry["sgv"]) {
                            return BloodSugar(value: Float(sgv), timestamp: timestamp, isMeteredBloodGlucoseValue: false, arrow: self.directionToArrow(entry["direction"] as? String ?? ""))
                        }
                        if let mbg = self.doubleValue(entry["mbg"]) {
                            return BloodSugar(value: Float(mbg), timestamp: timestamp, isMeteredBloodGlucoseValue: true, arrow: "-")
                        }
                        return nil
                    }.sorted { $0.timestamp < $1.timestamp }
                    let merged = self.mergeInTheNewData(oldValues: oldValues, newValues: parsed)
                    dispatchOnMain { resultHandler(.data(merged)) }
                } catch {
                    dispatchOnMain { resultHandler(.error(error)) }
                }
            }
        }
    }
    
    // append the oldvalues but leave duplicates
    fileprivate func mergeInTheNewData(oldValues : [BloodSugar], newValues : [BloodSugar]) -> [BloodSugar] {
        
        var mergedValues = oldValues
        for valueToInsert in newValues {
            guard !mergedValues.contains(where: { $0.timestamp == valueToInsert.timestamp && $0.isMeteredBloodGlucoseValue == valueToInsert.isMeteredBloodGlucoseValue }) else {
                continue
            }
            
            if let index = mergedValues.firstIndex(where: { $0.timestamp > valueToInsert.timestamp }) {
                mergedValues.insert(valueToInsert, at: index)
            } else {
                // the new value is later than all other values => just append
                mergedValues.append(valueToInsert)
            }
        }
        return mergedValues
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    /// Nightscout has returned entry dates as both millisecond numbers and
    /// ISO-8601 strings across API versions.
    private func timestampMillis(_ value: Any?) -> Double? {
        if let numeric = doubleValue(value) {
            return numeric
        }
        if let dateObject = value as? [String: Any],
           let nestedDate = dateObject["$date"] {
            return timestampMillis(nestedDate)
        }
        guard let isoString = value as? String,
              let date = ISO8601DateFormatter().date(from: isoString) else {
            return nil
        }
        return date.timeIntervalSince1970 * 1000
    }

    /// Returns the timestamp used for the server-side `created_at` filter.
    /// Older Nightscout records can lack `created_at`, so retain the v1
    /// `date`/`mills` fields as a compatibility fallback.
    private func treatmentCreatedAtTimestampMillis(_ treatment: [String: Any]) -> Double? {
        if let createdAt = treatment["created_at"] as? String, !createdAt.isEmpty {
            return Double.fromIsoString(isoTime: createdAt)
        }
        return doubleValue(treatment["mills"]) ?? timestampMillis(treatment["date"])
    }
    
    // appends the new value after the first value, which time is before the timestamp of newValue
    fileprivate func appendSingleValue(oldValues : [BloodSugar], newValue : BloodSugar) -> [BloodSugar] {
        
        if oldValues.count == 0 {
            return [newValue]
        }
        
        let reversedOldValues = Array(oldValues.reversed())
        var mergedValues = oldValues
        for (index, mergeValue) in reversedOldValues.enumerated() {
            if (mergeValue.timestamp < newValue.timestamp) {
                mergedValues.insert(newValue, at: index)
                return mergedValues
            }
        }
        
        return mergedValues
    }
    
    fileprivate func isDateColumn(_ cell : String) -> Bool {
        return cell.contains("-")
    }
    
    /* Reads all values from the day before. This is used for comparison with the current values. */
    @discardableResult
    func readYesterdaysChartData(_ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>) -> Void) -> NightscoutTask? {
        
        let calendar = Calendar.current
        let yesterday = TimeService.getYesterday()
        
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        let endOfYesterday = calendar.startOfDay(for: TimeService.getToday())
        
        return readChartDataWithinPeriodOfTime(oldValues: [], startOfYesterday, timestamp2: endOfYesterday, resultHandler: resultHandler)
    }
    
    func readYesterdaysChartData(_ resultHandler : @escaping ([BloodSugar]) -> Void) {
        
        self.readYesterdaysChartData { (result: NightscoutRequestResult<[BloodSugar]>)  in
            if case .data(let data) = result {
                resultHandler(data)
            }
        }
    }
    
    /* Reads all values from the current day. Beginning is 00:00 or
     the lastReceivedTime if this time is later than the current day at 00:00. */
    @discardableResult
    func readTodaysChartData(oldValues : [BloodSugar], _ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>) -> Void) -> NightscoutTask? {
        
        let calendar = Calendar.current
        let today = TimeService.getToday()
    
        let dayStart = calendar.startOfDay(for: today)
        var beginOfDay = dayStart
        // keep one hour, otherwise the complications and widgets would be empty and alarms for missing values could be triggered:
        let beginOfDayMinusOneHour = calendar.date(byAdding: .hour, value: -1, to: beginOfDay) ?? beginOfDay
        let endOfDay = calendar.startOfDay(for: TimeService.getTomorrow())

        // Do not let stale persisted values become part of the new request's
        // merge input. The one-hour transition grace period is retained, but
        // values from earlier days (or from the future) are discarded here.
        let sanitizedOldValues = oldValues.filter {
            $0.timestamp >= beginOfDayMinusOneHour.timeIntervalSince1970 * 1000 &&
            $0.timestamp < endOfDay.timeIntervalSince1970 * 1000
        }
        if sanitizedOldValues.count != oldValues.count {
            AppLogger.singleton.debug(
                "NightscoutService: discarded \(oldValues.count - sanitizedOldValues.count) stale cached glucose value(s) before today's request",
                category: .nightscout
            )
        }
        
        // use the current time so that we have to load the new values only
        let lastReceivedTime = determineTheLatestValueOf(oldValues: sanitizedOldValues)
        if lastReceivedTime > beginOfDayMinusOneHour {
            beginOfDay = lastReceivedTime
        }
        
        return readChartDataWithinPeriodOfTime(oldValues: sanitizedOldValues, beginOfDay, timestamp2: endOfDay, resultHandler: resultHandler)
    }
    
    fileprivate func determineTheLatestValueOf(oldValues : [BloodSugar]) -> Date {
        if oldValues.count == 0 || oldValues.last == nil {
            return Date.init(timeIntervalSince1970: 0)
        }
        
        return Date.init(timeIntervalSince1970: (oldValues.last?.timestamp ?? 0) / 1000)
    }
    
    @discardableResult
    func readDay(_ nrOfDaysAgo : Int, callbackHandler : @escaping (_ nrOfDay : Int, NightscoutRequestResult<[BloodSugar]>) -> Void) -> NightscoutTask? {
        let timeNrOfDaysAgo = TimeService.getNrOfDaysAgo(nrOfDaysAgo)
        
        let calendar = Calendar.current
        let startNrOfDaysAgo = calendar.startOfDay(for: timeNrOfDaysAgo)
        let endNrOfDaysAgo = startNrOfDaysAgo.addingTimeInterval(24 * 60 * 60)
        
        return readChartDataWithinPeriodOfTime(oldValues: [], startNrOfDaysAgo, timestamp2: endNrOfDaysAgo) { result in
            callbackHandler(nrOfDaysAgo, result)
        }
    }
    
    func readDay(_ nrOfDaysAgo : Int, callbackHandler : @escaping (_ nrOfDay : Int, [BloodSugar]) -> Void) {
        
        self.readDay(nrOfDaysAgo) { (nrOfDay: Int, result: NightscoutRequestResult<[BloodSugar]>)  in
            if case .data(let data) = result {
                callbackHandler(nrOfDay, data)
            }
        }
    }
    
    /* Reads all values from the last 2 Hours before. */
    @discardableResult
    func readLastTwoHoursChartData(_ resultHandler : @escaping (NightscoutRequestResult<[BloodSugar]>) -> Void) -> NightscoutTask? {
        
        let today = TimeService.getToday()
        let twoHoursBefore = today.addingTimeInterval(-60*120)
        
        return readChartDataWithinPeriodOfTime(oldValues : [], twoHoursBefore, timestamp2: today, resultHandler: resultHandler)
    }
    
    /* Reads the current blood glucose data used to display current value und delta */
    @discardableResult
    func readCurrentData(_ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>) -> Void) -> NightscoutTask? {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(.error(createEmptyOrInvalidUriError()))
            return nil
        }

        // Keep this compatibility helper v3-first. Normal UI code derives the
        // current value from the shared entries stream, but this method must
        // still honor the v3-first migration when called directly.
        AppLogger.singleton.debug(
            "NightscoutService: requesting current glucose through the v3 entries collection",
            category: .nightscout
        )
        return NightscoutAPIClient.shared.requestV3(
            path: "api/v3/entries",
            query: [
                "limit": "2",
                "sort$desc": "date",
                "fields": "identifier,_id,date,sgv,direction,units"
            ],
            legacy: NightscoutLegacyEndpoint(path: "api/v1/entries.json", query: ["count": "2"]),
            fallbackOnTransportFailure: true,
            legacyUseAccessTokenHeader: true
        ) { result in
            switch result {
            case .failure(let error):
                dispatchOnMain { resultHandler(.error(error)) }
            case .success(let response):
                do {
                    guard let entries = try JSONSerialization.jsonObject(with: response.0) as? [[String: Any]],
                          let latest = entries.max(by: { (self.timestampMillis($0["date"]) ?? 0) < (self.timestampMillis($1["date"]) ?? 0) }),
                          let latestValue = self.doubleValue(latest["sgv"]),
                          let latestDate = self.timestampMillis(latest["date"]) else {
                        throw self.createNoDataError(description: NSLocalizedString("No glucose data received from Nightscout.", comment: "No current glucose data"))
                    }

                    let nightscoutData = NightscoutData()
                    nightscoutData.sgv = String(format: "%.0f", latestValue)
                    nightscoutData.time = NSNumber(value: latestDate)
                    nightscoutData.bgdeltaArrow = self.directionToArrow(latest["direction"] as? String ?? "")

                    let previous = entries
                        .filter { (self.timestampMillis($0["date"]) ?? 0) < latestDate }
                        .max(by: { (self.timestampMillis($0["date"]) ?? 0) < (self.timestampMillis($1["date"]) ?? 0) })
                    if let previousValue = self.doubleValue(previous?["sgv"]) {
                        let delta = Float(latestValue - previousValue)
                        nightscoutData.bgdelta = delta
                        nightscoutData.bgdeltaString = String(format: "%+.0f", delta)
                    }

                    self.loadPropertiesEnrichment(into: nightscoutData) {
                        dispatchOnMain { resultHandler(.data(nightscoutData)) }
                    }
                } catch {
                    self.logServiceError("Current glucose response could not be decoded: \(error.localizedDescription)")
                    dispatchOnMain { resultHandler(.error(error)) }
                }
            }
        }
    }

    /// Derives the current glucose value and delta from an already synchronized
    /// entries snapshot. This intentionally performs no entries request.
    func makeCurrentData(
        from records: [NightscoutEntryRecord],
        enrichWithProperties: Bool = true,
        resultHandler: @escaping (NightscoutRequestResult<NightscoutData>) -> Void
    ) {
        let glucoseRecords = records
            .filter { $0.sgv != nil }
            .sorted { $0.dateMillis < $1.dateMillis }

        guard let latest = glucoseRecords.last,
              let latestValue = latest.sgv,
              latestValue.isFinite,
              latest.dateMillis > 0 else {
            let error = createNoDataError(description: NSLocalizedString("No glucose data received from Nightscout.", comment: "No current glucose data"))
            self.logServiceError("Current glucose could not be derived from the entries stream: \(error.localizedDescription)")
            dispatchOnMain { resultHandler(.error(error)) }
            return
        }

        let nightscoutData = NightscoutData()
        nightscoutData.sgv = String(format: "%.0f", latestValue)
        nightscoutData.time = NSNumber(value: latest.dateMillis)
        nightscoutData.bgdeltaArrow = directionToArrow(latest.direction ?? "")

        if glucoseRecords.count > 1 {
            let previous = glucoseRecords[glucoseRecords.count - 2]
            if let previousValue = previous.sgv {
                let delta = Float(latestValue - previousValue)
                nightscoutData.bgdelta = delta
                nightscoutData.bgdeltaString = String(format: "%+.0f", delta)
            }
        }

        guard enrichWithProperties else {
            dispatchOnMain { resultHandler(.data(nightscoutData)) }
            return
        }

        loadPropertiesEnrichment(into: nightscoutData) {
            dispatchOnMain { resultHandler(.data(nightscoutData)) }
        }
    }

    private func loadPropertiesEnrichment(into nightscoutData: NightscoutData, completion: @escaping () -> Void) {
        guard let url = UserDefaultsRepository.getUrlWithPathAndQueryParameters(path: "api/v2/properties", queryParams: [:]) else {
            completion()
            return
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logServiceWarning("Optional API v2 properties could not be loaded: \(error.localizedDescription)")
                completion()
                return
            }
            guard let http = response as? HTTPURLResponse else {
                self.logServiceWarning("Optional API v2 properties could not be loaded: invalid server response")
                completion()
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                self.logServiceWarning("Optional API v2 properties returned HTTP \(http.statusCode)")
                completion()
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.logServiceWarning("Optional API v2 properties returned invalid JSON")
                completion()
                return
            }

            if let upbat = json["upbat"] as? [String: Any], let display = upbat["display"] as? String {
                nightscoutData.battery = display
            }
            if let iob = json["iob"] as? [String: Any], let display = iob["display"] {
                nightscoutData.iob = "\(display)U"
            }
            if let cob = json["cob"] as? [String: Any], let display = self.doubleValue(cob["display"]) {
                nightscoutData.cob = String(format: "%.0fg", display)
            }
            if let delta = json["delta"] as? [String: Any], let mgdl = self.doubleValue(delta["mgdl"]) {
                nightscoutData.bgdelta = Float(mgdl)
                nightscoutData.bgdeltaString = (delta["display"] as? String) ?? String(format: "%+.0f", mgdl)
            }
            completion()
        }
        task.resume()
    }
    
    public func extractApiV2PropertiesData(data : Data, _ resultHandler : @escaping (NightscoutRequestResult<NightscoutData>) -> Void) {
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)
            guard let jsonDict :NSDictionary = json as? NSDictionary else {
                let error = NSError(domain: "APIV2PropertiesDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid JSON received from API V2 Properties", comment: "Invalid JSON received from API V2 Properties")])
                dispatchOnMain {
                    resultHandler(.error(error))
                }
                return
            }
            
            guard let bgnow = jsonDict.object(forKey: "bgnow") as? NSDictionary else {
                let error = NSError(domain: "APIV2PropertiesDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid JSON received from API V2 Properties, missing bgs data. Check Nightscout configuration.", comment: "Invalid JSON from API V2 Properties, missing bgs, check NS conf")])
                dispatchOnMain {
                    resultHandler(.error(error))
                }
                return
            }
            
            if bgnow.object(forKey: "last") == nil {
                if bgnow.object(forKey: "errors") != nil {
                    // Looks like we have values, but these are marked as erroneous
                    // Give a hint to the user by removing the old values and
                    // displaying empty data:
                    dispatchOnMain {
                        resultHandler(.data(NightscoutData()))
                    }
                    return
                }
                // if no more glucose values can't be retrieved: backout - so that the last retrieved value is preserved
                // this is useful to see how old the last retrieved value is
                return
            }
            let sgv : NSNumber = bgnow.object(forKey: "last") as? NSNumber ?? 0
            let time = bgnow.object(forKey: "mills") as? NSNumber ?? 0
            
            let upbat = jsonDict.object(forKey: "upbat") as? NSDictionary ?? NSDictionary()
            let nightscoutData = NightscoutData()
            nightscoutData.battery = upbat.object(forKey: "display") as? String ?? "?"
            
            //Get Insulin On Board from Nightscout
            let iobDict = jsonDict.object(forKey: "iob") as? NSDictionary ?? NSDictionary()
            if let iob = iobDict.object(forKey: "display") as? String {
                nightscoutData.iob = String(iob) + "U"
            }
            
            //Get Carbs On Board from Nightscout
            let cobDict = jsonDict.object(forKey: "cob") as? NSDictionary ?? NSDictionary()
            if let cob : Double = cobDict.object(forKey: "display") as? Double {
                nightscoutData.cob = cob.string(fractionDigits: 0) + "g"
            }
            
            nightscoutData.sgv = String(describing: sgv)
            nightscoutData.time = time
            
            nightscoutData.bgdeltaArrow = "-"
            if let sgvs = bgnow["sgvs"] as? [[String: Any]],
               let firstSgv = sgvs.first,
               let direction = firstSgv["direction"] as? String {
                
                nightscoutData.bgdeltaArrow = self.directionToArrow(direction)
            }
            
            let deltaDict = jsonDict.object(forKey: "delta") as? NSDictionary ?? NSDictionary()
            nightscoutData.bgdeltaString = deltaDict.object(forKey: "display") as? String ?? "?"
            nightscoutData.bgdelta = deltaDict.object(forKey: "mgdl") as? Float ?? 0.0
            
            dispatchOnMain {
                resultHandler(.data(nightscoutData))
            }
            
        } catch {
            #if MAIN_APP
            AppLogger.singleton.error("NightscoutService: Catched unknown exception at status parse.")
            #endif
            let error = NSError(domain: "PebbleWatchDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Unknown error while extracting data from Pebble Watch API", comment: "Unkown error while extracting Pebble API data")])
            
            dispatchOnMain {
                resultHandler(.error(error))
            }
            return
        }
    }
    
    // Converts the pebbles direction number to unicode arrow characters
    fileprivate func getDirectionCharacter(_ directionNumber : NSNumber) -> String {
        
        return DIRECTIONS[directionNumber.intValue]
    }
    
    fileprivate func direction(_ delta : Float) -> String {
        if (delta >= 0) {
            return "+"
        }
        return ""
    }
    
    fileprivate func formatTime(_ secondsSince01011970 : NSNumber) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dateString : String = timeFormatter.string(from: Date(timeIntervalSince1970: secondsSince01011970.doubleValue / 1000))
        return dateString
    }
    
    fileprivate func getNoiseLevel(_ noiseCode : Int, sgv: String) -> String {
        
        // as implemented in https://github.com/nightscout/cgm-remote-monitor/blob/d407bab2096d739708f365eae3c78847291bc997/lib/plugins/rawbg.js
        switch noiseCode {
        case 0:
            return "---"
        case 1:
            return "Clean"
        case 2:
            return "Light"
        case 3:
            return "Medium"
        case 4:
            return "Heavy"
        default:
            if UnitsConverter.displayValueToMgdl(sgv) < 40.0 {
                return "Heavy"
            } else {
                return "~~~"
            }
        }
    }
    
    /* Reads the treatment record for the last cannula change, sensor change and battery age */
    @discardableResult
    func readLastTreatementEventTimestamp(eventType : EventType, daysToGoBackInTime : Int, resultHandler : @escaping (Date) -> Void) -> NightscoutTask? {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(Date())
            return nil
        }
        let daysBackInTime = Calendar.current.date(
                byAdding: .day, value: -daysToGoBackInTime, to: Date()) ?? Date()
        let legacyQuery = [
            "find[eventType]" : eventType.rawValue,
            "find[created_at][$gte]" :  daysBackInTime.convertToIsoDateTime(),
            "count" : "1"
        ]

        return NightscoutAPIClient.shared.requestV3(
            path: "api/v3/treatments",
            query: [
                "eventType$eq": eventType.rawValue,
                "created_at$gte": daysBackInTime.convertToIsoDateTime(),
                "sort$desc": "created_at",
                "limit": "1",
                "fields": "created_at,date"
            ],
            legacy: NightscoutLegacyEndpoint(path: "api/v1/treatments", query: legacyQuery)
        ) { result in
            guard case .success(let response) = result,
                  let treatments = try? JSONSerialization.jsonObject(with: response.0) as? [[String: Any]],
                  let treatment = treatments.first else {
                AppLogger.singleton.warning("NightscoutService: no \(eventType.rawValue) treatment was returned", category: .nightscout)
                dispatchOnMain { resultHandler(Date()) }
                return
            }
            let cutoff = daysBackInTime.timeIntervalSince1970 * 1000
            guard let createdAt = self.treatmentCreatedAtTimestampMillis(treatment), createdAt >= cutoff else {
                AppLogger.singleton.warning(
                    "NightscoutService: \(eventType.rawValue) result was outside the requested time range",
                    category: .nightscout
                )
                dispatchOnMain { resultHandler(Date()) }
                return
            }

            let date: Date
            if let createdAt = treatment["created_at"] as? String {
                date = Date.fromIsoString(isoTime: createdAt)
            } else if let timestamp = self.timestampMillis(treatment["date"]) {
                date = Date(timeIntervalSince1970: timestamp / 1000)
            } else {
                date = Date()
            }
            dispatchOnMain { resultHandler(date) }
        }
    }
    
    func readLastTemporaryTarget(daysToGoBackInTime : Int, resultHandler : @escaping (TemporaryTargetData?) -> Void) {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(nil)
            return
        }
        let since = Calendar.current.date(byAdding: .day, value: -daysToGoBackInTime, to: Date()) ?? Date()
        let legacyQuery = [
            "find[eventType]" : "Temporary Target",
            "find[created_at][$gte]" : since.convertToIsoDateTime(),
            "count" : "1"
        ]

        _ = NightscoutAPIClient.shared.requestV3(
            path: "api/v3/treatments",
            query: [
                "eventType$eq": "Temporary Target",
                "created_at$gte": since.convertToIsoDateTime(),
                "sort$desc": "created_at",
                "limit": "1"
            ],
            legacy: NightscoutLegacyEndpoint(path: "api/v1/treatments", query: legacyQuery)
        ) { result in
            guard case .success(let response) = result,
                  let treatments = try? JSONSerialization.jsonObject(with: response.0) as? [[String: Any]],
                  let first = treatments.first else {
                AppLogger.singleton.warning("NightscoutService: temporary target could not be loaded", category: .nightscout)
                dispatchOnMain { resultHandler(nil) }
                return
            }
            let cutoff = since.timeIntervalSince1970 * 1000
            guard let createdAt = self.treatmentCreatedAtTimestampMillis(first), createdAt >= cutoff else {
                AppLogger.singleton.warning(
                    "NightscoutService: temporary target result was outside the requested time range",
                    category: .nightscout
                )
                dispatchOnMain { resultHandler(nil) }
                return
            }

            let temporaryTarget = TemporaryTarget.parse(temporaryTargetDict: first)
            let data = TemporaryTargetData()
            data.targetTop = temporaryTarget.targetTop
            data.targetBottom = temporaryTarget.targetBottom
            data.activeUntilDate = self.calculateEndDate(createdAt: temporaryTarget.createdAt, durationInMinutes: temporaryTarget.duration)
            dispatchOnMain { resultHandler(data) }
        }
    }
    
    func createTemporaryTarget(reason: String, target: Int, durationInMinutes: Int, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        createTreatment([
            "eventType": "Temporary Target",
            "duration": durationInMinutes,
            "reason": reason,
            "targetBottom": target,
            "targetTop": target,
            "units": "mg/dl"
        ], eventDate: Date(), resultHandler: resultHandler)
    }
    
    /* Deleting works by setting a temporary target with duration 0 */
    func deleteTemporaryTarget(resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        createTreatment([
            "eventType": "Temporary Target",
            "duration": 0,
            "reason": "Canceled"
        ], eventDate: Date(), resultHandler: resultHandler)
    }
    
    private func calculateEndDate(createdAt : String?, durationInMinutes : Int?) -> Date {
        
        if let createdAt = createdAt, let durationInMinutes = durationInMinutes {
            let creationDate = Date.fromIsoString(isoTime: createdAt)
            return Calendar.current.date(byAdding: .minute, value: durationInMinutes, to: creationDate) ?? Date()
        }
        
        return Date()
    }
    
    func createCarbsCorrection(carbs: Int, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        createTreatment([
            "eventType": "Carb Correction",
            "carbs": carbs,
            "duration": 0
        ], eventDate: Date(), resultHandler: resultHandler)
    }
    
    func createCannulaChangeTreatment(changeDate: Date, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        createChangeTreatment(eventType: .cannulaChange, changeDate: changeDate, resultHandler: resultHandler)
    }
    
    func createSensorChangeTreatment(changeDate: Date, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        createChangeTreatment(eventType: .sensorStart, changeDate: changeDate, resultHandler: resultHandler)
    }
    
    func createBatteryChangeTreatment(changeDate: Date, resultHandler : @escaping (_ errorMessage : String?) -> Void) {
        createChangeTreatment(eventType: .pumpBatteryChange, changeDate: changeDate, resultHandler: resultHandler)
    }

    private func createChangeTreatment(eventType: EventType, changeDate: Date, resultHandler: @escaping (String?) -> Void) {
        createTreatment([
            "eventType": eventType.rawValue,
            "notes": "",
            "carbs": NSNull(),
            "insulin": NSNull()
        ], eventDate: changeDate, resultHandler: resultHandler)
    }

    private func createTreatment(_ fields: [String: Any], eventDate: Date, resultHandler: @escaping (String?) -> Void) {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(NSLocalizedString("The Nightscout URL is empty.", comment: "Missing Nightscout URL"))
            return
        }
        guard !UserDefaultsRepository.nightscoutToken.isEmpty else {
            resultHandler(NSLocalizedString("An API token is required for Care actions.", comment: "Missing Nightscout token"))
            return
        }

        var document = fields
        document["date"] = eventDate.toUTCMillis()
        document["app"] = "nightguard"
        document["enteredBy"] = "nightguard"
        document["created_at"] = eventDate.convertToIsoDateTime()
        document["mills"] = eventDate.toUTCMillis()

        guard let body = try? JSONSerialization.data(withJSONObject: document) else {
            resultHandler(NSLocalizedString("The treatment could not be encoded.", comment: "Treatment encoding error"))
            return
        }
        let legacyQuery = ["now": String(describing: Date.timeIntervalSince(Date()))]
        _ = NightscoutAPIClient.shared.requestV3(
            path: "api/v3/treatments",
            method: "POST",
            body: body,
            legacy: NightscoutLegacyEndpoint(path: "api/v1/treatments", query: legacyQuery)
        ) { result in
            dispatchOnMain {
                switch result {
                case .success: resultHandler(nil)
                case .failure(let error): resultHandler(error.localizedDescription)
                }
            }
        }
    }
    
    /* Reads the devicestatus to get pump basal rate and profile */
    @discardableResult
    func readDeviceStatus(resultHandler : @escaping (DeviceStatusData) -> Void) -> NightscoutTask? {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler(DeviceStatusData())
            return nil
        }

        // cgm-remote-monitor serves this exact v1 query from its in-memory
        // devicestatus cache (when `count` is the only query parameter). The
        // generic v3 search has to query MongoDB and can become very slow on
        // large devicestatus collections, so use the cache-friendly endpoint
        // for this non-critical, read-only status panel.
        AppLogger.singleton.debug(
            "NightscoutService: requesting device status through the cache-friendly v1 endpoint",
            category: .nightscout
        )
        return NightscoutAPIClient.shared.requestLegacy(
            path: "api/v1/devicestatus.json",
            query: ["count": "5"],
            useAccessTokenHeader: true
        ) { result in
            guard case .success(let response) = result,
                  let statuses = try? JSONSerialization.jsonObject(with: response.0) as? [[String: Any]] else {
                AppLogger.singleton.warning("NightscoutService: device status could not be loaded", category: .nightscout)
                dispatchOnMain { resultHandler(DeviceStatusData()) }
                return
            }
            dispatchOnMain { resultHandler(self.deviceStatusData(from: statuses)) }
        }
    }

    private func deviceStatusData(from statuses: [[String: Any]]) -> DeviceStatusData {
        for status in statuses {
            guard let pump = status["pump"] as? [String: Any] else { continue }
            let reservoir = Int(doubleValue(pump["reservoir"]) ?? 0)
            guard let extended = pump["extended"] as? [String: Any] else {
                return DeviceStatusData(activePumpProfile: "---", pumpProfileActiveUntil: nil, reservoirUnits: reservoir, temporaryBasalRate: "--", temporaryBasalRateActiveUntil: Date())
            }
            guard let activeProfile = extended["ActiveProfile"] as? String else { continue }
            return DeviceStatusData(
                activePumpProfile: activeProfile,
                pumpProfileActiveUntil: nil,
                reservoirUnits: reservoir,
                temporaryBasalRate: calculateTempBasalPercentage(baseBasalRate: extended["BaseBasalRate"], tempBasalAbsoluteRate: extended["TempBasalAbsoluteRate"]),
                temporaryBasalRateActiveUntil: calculateTempBasalEndTime(tempBasalRemainingMinutes: extended["TempBasalRemaining"])
            )
        }
        return DeviceStatusData()
    }
    
    // Read today's treatments. Keep the server-side filter precise and apply
    // the same filter locally as a safeguard for older Nightscout versions
    // that ignore one of the operators.
    @discardableResult
    func readLatestTreatements(resultHandler : @escaping ([[String:Any]]) -> Void) -> NightscoutTask? {
        guard !UserDefaultsRepository.baseUri.value.isEmpty else {
            resultHandler([])
            return nil
        }

        let startOfDayDate = Calendar.current.startOfDay(for: Date())
        let startOfDay = startOfDayDate.convertToIsoDateTime()
        let startOfDayMillis = startOfDayDate.timeIntervalSince1970 * 1000
        let eventTypes: Set<String> = [
            "Carb Correction",
            "Meal Bolus",
            "Correction Bolus",
            "Bolus Wizard"
        ]
        let legacyQuery = [
            "find[created_at][$gte]": startOfDay,
            "count": "500"
        ]
        return NightscoutAPIClient.shared.requestV3(
            path: "api/v3/treatments",
            query: [
                "created_at$gte": startOfDay,
                "eventType$in": "Carb Correction|Meal Bolus|Correction Bolus|Bolus Wizard",
                "sort$desc": "created_at",
                "limit": "500"
            ],
            legacy: NightscoutLegacyEndpoint(path: "api/v1/treatments.json", query: legacyQuery)
        ) { result in
            guard case .success(let response) = result,
                  let treatments = try? JSONSerialization.jsonObject(with: response.0) as? [[String: Any]] else {
                AppLogger.singleton.warning("NightscoutService: latest treatments could not be loaded", category: .nightscout)
                dispatchOnMain { resultHandler([]) }
                return
            }
            let filteredTreatments = treatments
                .filter { treatment in
                    guard let eventType = treatment["eventType"] as? String,
                          eventTypes.contains(eventType),
                          let createdAt = self.treatmentCreatedAtTimestampMillis(treatment) else {
                        return false
                    }
                    return createdAt >= startOfDayMillis
                }
                .sorted { left, right in
                    let leftDate = self.treatmentCreatedAtTimestampMillis(left) ?? 0
                    let rightDate = self.treatmentCreatedAtTimestampMillis(right) ?? 0
                    return leftDate > rightDate
                }

            if filteredTreatments.count != treatments.count {
                AppLogger.singleton.debug(
                    "NightscoutService: filtered \(treatments.count - filteredTreatments.count) old or unrelated treatment(s) from the response",
                    category: .nightscout
                )
            }
            dispatchOnMain { resultHandler(filteredTreatments) }
        }
    }
    
    
    private func calculateTempBasalPercentage(baseBasalRate: Any?, tempBasalAbsoluteRate: Any?) -> String {
        
        guard let baseBasalRateAsDouble = Double.fromAny(baseBasalRate as Any) else {
            return ""
        }
        if (tempBasalAbsoluteRate == nil) {
            return ""
        }
        guard let tempBasalAbsoluteRateAsDouble = Double.fromAny(tempBasalAbsoluteRate as Any) else {
            return ""
        }
        
        return Double(tempBasalAbsoluteRateAsDouble / baseBasalRateAsDouble * 100).rounded().string(fractionDigits: 0)
    }
    
    private func calculateTempBasalEndTime(tempBasalRemainingMinutes: Any?) -> Date {
        
        if let tempBasalRemainingMinutesAsInt = tempBasalRemainingMinutes as? Int {
            
            return Calendar.current.date(byAdding: .minute, value: tempBasalRemainingMinutesAsInt, to: Date()) ?? Date()
        }
        return Date()
    }

    private func logServiceError(_ message: String) {
        AppLogger.singleton.error("NightscoutService: \(message)", category: .nightscout)
    }

    private func logServiceWarning(_ message: String) {
        AppLogger.singleton.warning("NightscoutService: \(message)", category: .nightscout)
    }
    
    private func createEmptyOrInvalidUriError() -> Error {
        return NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo:  [NSLocalizedDescriptionKey: NSLocalizedString("The base URI is empty or invalid!", comment: "Empty or invalid Uri error")])
    }
    
    private func createNoDataError(description: String ) -> Error {
        return NSError(domain: "NightguardError", code: -1, userInfo: [NSLocalizedDescriptionKey: description])
    }
    
    private func createUnauthorizedError(description: String ) -> Error {
        return NSError(domain: "NightguardError", code: -1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
