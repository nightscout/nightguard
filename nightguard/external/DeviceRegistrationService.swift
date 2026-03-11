//
//  DeviceRegistrationService.swift
//  nightguard
//
//  Created by JamOrHam on 27/02/2026.
//

import Foundation

// register our device information to the server for push notifications

final class DeviceRegistrationService {

    static let shared = DeviceRegistrationService()

    private init() {}

    // MARK: - Keys

    private let tokenKey = "apns_token"
    private let environmentKey = "apns_environment"
    private let lastRegisteredTokenKey = "last_registered_token"

    // MARK: - Computed URL

    private var registrationURL: URL? {
        UserDefaultsRepository
            .getUrlWithPathAndQueryParameters(
                path: "api/v1/registration",
                queryParams: [:]
            )
    }

    // MARK: - Public API

    /// Called when token received
    func updateDeviceToken(_ token: String, environment: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(environment, forKey: environmentKey)

        registerIfPossible()
    }

    /// Called when user finishes configuring server URL
    func configurationDidUpdate() {
        // Invalidate previous registration
        UserDefaults.standard.removeObject(forKey: lastRegisteredTokenKey)

        registerIfPossible()
    }

    /// Safe to call anytime
    func registerIfPossible() {

        guard
            let token = UserDefaults.standard.string(forKey: tokenKey),
            let environment = UserDefaults.standard.string(forKey: environmentKey),
            let registrationURL = registrationURL
        else {
            Logger.log("Push registration: Missing token or registration URL. Skipping.")
            return
        }

        // Avoid duplicate registrations
        if token == UserDefaults.standard.string(forKey: lastRegisteredTokenKey) {
            Logger.log("Push registration: Token already registered. Skipping.")
            return
        }

        sendRegistration(token: token,
                         environment: environment,
                         url: registrationURL)
    }
    
    // determine if this is sandbox apn or not
    func apnsEnvironment() -> String {
        guard
            let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
            let data = try? Data(contentsOf: url),
            let string = String(data: data, encoding: .ascii),
            let range = string.range(of: "<key>aps-environment</key>")
        else { return "error" }

        let sub = string[range.upperBound...]
        if sub.range(of: "<string>development</string>") != nil {
            return "sandbox"
        } else if sub.range(of: "<string>production</string>") != nil {
            return "production"
        }
        return "unknown"
    }
    // MARK: - Private

    private func sendRegistration(token: String,
                                  environment: String,
                                  url: URL) {

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "deviceToken": token,
            "environment": environment,
            "bundle": Bundle.main.bundleIdentifier ?? "",
            "platform": "ios"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                Logger.log("Push registration error: \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.log("Push registration: Invalid server response")
                return
            }

            if httpResponse.statusCode == 200 {
                Logger.log("Push registration: Device successfully registered")

                UserDefaults.standard.set(token,
                                          forKey: self.lastRegisteredTokenKey)

            } else {
                Logger.log("Push registration: Bad status code: \(httpResponse.statusCode)")
            }
        }

        task.resume()
    }
}
