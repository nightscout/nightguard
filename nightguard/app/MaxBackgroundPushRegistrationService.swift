//
//  MaxBackgroundPushRegistrationService.swift
//  nightguard
//

import Foundation
import UIKit
import StoreKit

final class MaxBackgroundPushRegistrationService {
    static let shared = MaxBackgroundPushRegistrationService()

    private let tokenKey = "maxBackgroundPushDeviceToken"
    private let registrationTokenKey = "maxBackgroundPushRegisteredToken"
    private let backendURLKey = "MAX_BACKEND_BASE_URL"
    private let appCheckTokenKey = "MAX_BACKEND_APP_CHECK_TOKEN"

    private init() {}

    func configureForCurrentEntitlement() {
        DispatchQueue.main.async {
            if PurchaseManager.shared.isMaxAccessAvailable {
                UIApplication.shared.registerForRemoteNotifications()
                self.registerStoredTokenIfPossible()
            } else {
                self.unregisterStoredTokenIfNeeded()
            }
        }
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        registerStoredTokenIfPossible()
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        AppLogger.singleton.error("APNs registration failed: \(error.localizedDescription)", category: .backgroundUpdates)
    }

    private func registerStoredTokenIfPossible() {
        guard PurchaseManager.shared.isMaxAccessAvailable else { return }
        guard let deviceToken = UserDefaults.standard.string(forKey: tokenKey), !deviceToken.isEmpty else { return }
        guard let backendBaseURL = NightguardEnvironment.value(for: backendURLKey), !backendBaseURL.isEmpty else {
            AppLogger.singleton.warning("MAX_BACKEND_BASE_URL missing; skipping Max device registration", category: .backgroundUpdates)
            return
        }

        if UserDefaults.standard.string(forKey: registrationTokenKey) == deviceToken {
            return
        }

        Task {
            do {
                let transactionJWS = try await PurchaseManager.shared.currentMaxTransactionJWS()
                try await sendRegistration(deviceToken: deviceToken, transactionJWS: transactionJWS, backendBaseURL: backendBaseURL)
                UserDefaults.standard.set(deviceToken, forKey: registrationTokenKey)
                AppLogger.singleton.info("Registered Max device for silent APNs", category: .backgroundUpdates)
            } catch {
                AppLogger.singleton.error("Max device registration failed: \(error.localizedDescription)", category: .backgroundUpdates)
            }
        }
    }

    private func unregisterStoredTokenIfNeeded() {
        guard let registeredToken = UserDefaults.standard.string(forKey: registrationTokenKey), !registeredToken.isEmpty else { return }
        guard let backendBaseURL = NightguardEnvironment.value(for: backendURLKey), !backendBaseURL.isEmpty else {
            UserDefaults.standard.removeObject(forKey: registrationTokenKey)
            return
        }

        Task {
            do {
                try await sendUnregistration(deviceToken: registeredToken, backendBaseURL: backendBaseURL)
            } catch {
                AppLogger.singleton.warning("Max device unregistration failed: \(error.localizedDescription)", category: .backgroundUpdates)
            }
            UserDefaults.standard.removeObject(forKey: registrationTokenKey)
        }
    }

    private func sendRegistration(deviceToken: String, transactionJWS: String, backendBaseURL: String) async throws {
        var request = try makeRequest(path: "/api/devices/register", backendBaseURL: backendBaseURL)
        await applyAppCheckHeader(to: &request)
        let environment = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "sandbox" : "production"
        request.httpBody = try JSONEncoder().encode(DeviceRegistrationRequest(
            deviceToken: deviceToken,
            transactionJWS: transactionJWS,
            bundleId: Bundle.main.bundleIdentifier ?? "de.my-wan.dhe.nightguard",
            environment: environment
        ))
        let response = try await perform(request: request)
        try validate(response: response)
    }

    private func sendUnregistration(deviceToken: String, backendBaseURL: String) async throws {
        var request = try makeRequest(path: "/api/devices/unregister", backendBaseURL: backendBaseURL)
        await applyAppCheckHeader(to: &request)
        request.httpBody = try JSONEncoder().encode(DeviceUnregistrationRequest(deviceToken: deviceToken))
        let response = try await perform(request: request)
        try validate(response: response)
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
            return
        }

        if let appCheckToken = NightguardEnvironment.value(for: appCheckTokenKey), !appCheckToken.isEmpty {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RegistrationError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RegistrationError.serverStatus(httpResponse.statusCode)
        }
    }

    private func perform(request: URLRequest) async throws -> URLResponse {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let response = response else {
                    continuation.resume(throwing: RegistrationError.invalidResponse)
                    return
                }

                continuation.resume(returning: response)
            }
            task.resume()
        }
    }

    private struct DeviceRegistrationRequest: Encodable {
        let deviceToken: String
        let transactionJWS: String
        let bundleId: String
        let environment: String
    }

    private struct DeviceUnregistrationRequest: Encodable {
        let deviceToken: String
    }

    private enum RegistrationError: LocalizedError {
        case invalidBackendURL
        case invalidResponse
        case serverStatus(Int)

        var errorDescription: String? {
            switch self {
            case .invalidBackendURL:
                return "Invalid Max backend URL"
            case .invalidResponse:
                return "Invalid Max backend response"
            case .serverStatus(let status):
                return "Max backend returned HTTP \(status)"
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
