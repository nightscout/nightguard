//
//  MaxBackgroundPushRegistrationService.swift
//  nightguard
//

import Foundation
import UIKit
import StoreKit
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

final class MaxBackgroundPushRegistrationService {
    static let shared = MaxBackgroundPushRegistrationService()

    private let tokenKey = "maxBackgroundPushFCMToken"
    private let registrationTokenKey = "maxBackgroundPushRegisteredToken"
    private let backendURLKey = "MAX_BACKEND_BASE_URL"
    private let defaultBackendBaseURL = "https://nightguard-backend--nightguard-app.europe-west4.hosted.app"
    private let appCheckTokenKey = "MAX_BACKEND_APP_CHECK_TOKEN"
    private var hasAPNsToken = false

    private init() {}

    func configureForCurrentEntitlement() {
        DispatchQueue.main.async {
            if PurchaseManager.shared.isMaxAccessAvailable {
                AppLogger.singleton.debug("Max entitlement active; starting silent push registration flow", category: .backgroundUpdates)
                UIApplication.shared.registerForRemoteNotifications()
                self.registerStoredTokenIfPossible()
            } else {
                AppLogger.singleton.debug("Max entitlement inactive; starting silent push unregistration flow", category: .backgroundUpdates)
                self.unregisterStoredTokenIfNeeded()
            }
        }
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        hasAPNsToken = true
        AppLogger.singleton.info("APNs returned device token for Max FCM registration", category: .backgroundUpdates)
        fetchFCMTokenIfPossible()
    }

    func didReceiveFCMToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        AppLogger.singleton.info("FCM returned token for Max registration: token=\(maskedToken(token))", category: .backgroundUpdates)
        registerStoredTokenIfPossible()
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        AppLogger.singleton.error("APNs registration failed: \(error.localizedDescription)", category: .backgroundUpdates)
    }

    private func registerStoredTokenIfPossible() {
        guard PurchaseManager.shared.isMaxAccessAvailable else {
            AppLogger.singleton.debug("Skipping Max device registration: Max access is unavailable", category: .backgroundUpdates)
            return
        }

        guard let fcmToken = UserDefaults.standard.string(forKey: tokenKey), !fcmToken.isEmpty else {
            AppLogger.singleton.warning("Skipping Max device registration: no FCM token stored yet", category: .backgroundUpdates)
            fetchFCMTokenIfPossible()
            return
        }

        let backendBaseURL = resolvedBackendBaseURL()
        let registrationMarker = fcmToken

        if UserDefaults.standard.string(forKey: registrationTokenKey) == registrationMarker {
            AppLogger.singleton.info("Skipping Max device registration: FCM token already registered locally token=\(maskedToken(fcmToken))", category: .backgroundUpdates)
            return
        }

        Task {
            do {
                AppLogger.singleton.debug("Preparing Max device registration: backend=\(backendDescription(backendBaseURL)), bundleId=\(bundleId), fcmToken=\(maskedToken(fcmToken))", category: .backgroundUpdates)
                let transactionJWS = try await PurchaseManager.shared.currentMaxTransactionJWS()
                AppLogger.singleton.debug("Max StoreKit transaction available; sending device registration", category: .backgroundUpdates)
                try await sendRegistration(fcmToken: fcmToken, transactionJWS: transactionJWS, backendBaseURL: backendBaseURL)
                UserDefaults.standard.set(registrationMarker, forKey: registrationTokenKey)
                AppLogger.singleton.info("Registered Max device for silent FCM push: token=\(maskedToken(fcmToken))", category: .backgroundUpdates)
            } catch {
                AppLogger.singleton.error("Max device registration failed for token=\(maskedToken(fcmToken)): \(error.localizedDescription)", category: .backgroundUpdates)
            }
        }
    }

    private func unregisterStoredTokenIfNeeded() {
        guard let registeredMarker = UserDefaults.standard.string(forKey: registrationTokenKey), !registeredMarker.isEmpty else {
            AppLogger.singleton.debug("Skipping Max device unregistration: no locally registered FCM token exists", category: .backgroundUpdates)
            return
        }
        let registeredToken = registeredMarker

        let backendBaseURL = resolvedBackendBaseURL()

        Task {
            do {
                AppLogger.singleton.debug("Sending Max device unregistration: backend=\(backendDescription(backendBaseURL)), token=\(maskedToken(registeredToken))", category: .backgroundUpdates)
                try await sendUnregistration(fcmToken: registeredToken, backendBaseURL: backendBaseURL)
                AppLogger.singleton.info("Unregistered Max device for silent FCM push: token=\(maskedToken(registeredToken))", category: .backgroundUpdates)
            } catch {
                AppLogger.singleton.warning("Max device unregistration failed for token=\(maskedToken(registeredToken)): \(error.localizedDescription)", category: .backgroundUpdates)
            }
            UserDefaults.standard.removeObject(forKey: registrationTokenKey)
            AppLogger.singleton.debug("Removed local Max registration marker for token=\(maskedToken(registeredToken))", category: .backgroundUpdates)
        }
    }

    private func fetchFCMTokenIfPossible() {
        guard PurchaseManager.shared.isMaxAccessAvailable else {
            return
        }
        guard hasAPNsToken else {
            AppLogger.singleton.debug("Skipping FCM token fetch: waiting for APNs token", category: .backgroundUpdates)
            return
        }

        #if canImport(FirebaseMessaging)
        Task {
            do {
                let token = try await Messaging.messaging().token()
                didReceiveFCMToken(token)
            } catch {
                AppLogger.singleton.error("FCM token fetch failed: \(error.localizedDescription)", category: .backgroundUpdates)
            }
        }
        #else
        AppLogger.singleton.error("FirebaseMessaging is unavailable; Max silent push registration cannot continue", category: .backgroundUpdates)
        #endif
    }

    private func sendRegistration(fcmToken: String, transactionJWS: String, backendBaseURL: String) async throws {
        var request = try makeRequest(path: "/api/devices/register", backendBaseURL: backendBaseURL)
        await applyAppCheckHeader(to: &request)
        request.httpBody = try JSONEncoder().encode(DeviceRegistrationRequest(
            fcmToken: fcmToken,
            transactionJWS: transactionJWS,
            bundleId: bundleId
        ))
        let (data, response) = try await perform(request: request)
        try validate(response: response, data: data)
    }

    private func sendUnregistration(fcmToken: String, backendBaseURL: String) async throws {
        var request = try makeRequest(path: "/api/devices/unregister", backendBaseURL: backendBaseURL)
        await applyAppCheckHeader(to: &request)
        request.httpBody = try JSONEncoder().encode(DeviceUnregistrationRequest(fcmToken: fcmToken))
        let (data, response) = try await perform(request: request)
        try validate(response: response, data: data)
    }

    private func makeRequest(path: String, backendBaseURL: String) throws -> URLRequest {
        guard let url = URL(string: backendBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path) else {
            throw RegistrationError.invalidBackendURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }

    private func applyAppCheckHeader(to request: inout URLRequest) async {
        if let token = await MaxBackendAppCheckService.shared.token(), !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
            AppLogger.singleton.debug("Using Firebase App Check token for Max backend request", category: .backgroundUpdates)
            return
        }

        if let appCheckToken = NightguardEnvironment.value(for: appCheckTokenKey), !appCheckToken.isEmpty {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
            AppLogger.singleton.warning("Using fallback MAX_BACKEND_APP_CHECK_TOKEN for Max backend request", category: .backgroundUpdates)
        } else {
            AppLogger.singleton.warning("No Firebase App Check token or fallback token available for Max backend request", category: .backgroundUpdates)
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RegistrationError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RegistrationError.serverStatus(httpResponse.statusCode, responseBodyDescription(data))
        }
    }

    private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let response = response else {
                    continuation.resume(throwing: RegistrationError.invalidResponse)
                    return
                }

                continuation.resume(returning: (data ?? Data(), response))
            }
            task.resume()
        }
    }

    private struct DeviceRegistrationRequest: Encodable {
        let fcmToken: String
        let transactionJWS: String
        let bundleId: String
    }

    private struct DeviceUnregistrationRequest: Encodable {
        let fcmToken: String
    }

    private var bundleId: String {
        Bundle.main.bundleIdentifier ?? "de.my-wan.dhe.nightguard"
    }

    private func resolvedBackendBaseURL() -> String {
        if let configuredBackendBaseURL = NightguardEnvironment.value(for: backendURLKey), !configuredBackendBaseURL.isEmpty {
            return configuredBackendBaseURL
        }

        AppLogger.singleton.warning("MAX_BACKEND_BASE_URL missing; using default Max backend", category: .backgroundUpdates)
        return defaultBackendBaseURL
    }

    private func maskedToken(_ token: String) -> String {
        guard !token.isEmpty else { return "<empty>" }
        let suffixLength = min(8, token.count)
        return "...\(token.suffix(suffixLength))"
    }

    private func backendDescription(_ backendBaseURL: String) -> String {
        guard let url = URL(string: backendBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) else {
            return "<invalid url>"
        }

        let host = url.host ?? "<missing host>"
        let path = url.path.isEmpty ? "" : url.path
        return "\(host)\(path)"
    }

    private func responseBodyDescription(_ data: Data) -> String {
        guard !data.isEmpty else { return "empty response body" }

        let responseBody = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !responseBody.isEmpty else { return "non-text response body" }

        return String(responseBody.prefix(300))
    }

    private enum RegistrationError: LocalizedError {
        case invalidBackendURL
        case invalidResponse
        case serverStatus(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidBackendURL:
                return "Invalid Max backend URL"
            case .invalidResponse:
                return "Invalid Max backend response"
            case .serverStatus(let status, let body):
                return "Max backend returned HTTP \(status): \(body)"
            }
        }
    }
}

enum NightguardEnvironment {
    static func value(for key: String) -> String? {
        if let infoValue = Bundle.main.object(forInfoDictionaryKey: key) as? String, !infoValue.isEmpty {
            return infoValue
        }

        guard let filePath = Bundle.main.path(forResource: ".env", ofType: nil),
              let contents = try? String(contentsOfFile: filePath) else {
            return nil
        }

        for line in contents.components(separatedBy: .newlines) {
            let parts = line.split(separator: "=", maxSplits: 1).map { String($0) }
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespacesAndNewlines) == key {
                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }
}
