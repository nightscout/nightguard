import Foundation

enum MaxPushRegistration: Equatable {
    case unresolved
    case inactive
    case active(token: String, jws: String, marker: String)
}

/// Serializes backend changes, retaining failed operations for the next check.
@MainActor
final class MaxPushRegistrationCoordinator {
    static let tokenKey = "maxBackgroundPushRegisteredToken"
    static let markerKey = "maxBackgroundPushRegistrationMarker"
    private let defaults: UserDefaults
    private let desiredRegistration: () async -> MaxPushRegistration
    private let register: (String, String) async throws -> Void
    private let unregister: (String) async throws -> Void
    private let onError: (Error) -> Void
    private var task: Task<Void, Never>?
    private var pending = false

    init(defaults: UserDefaults = .standard,
         desiredRegistration: @escaping () async -> MaxPushRegistration,
         register: @escaping (String, String) async throws -> Void,
         unregister: @escaping (String) async throws -> Void,
         onError: @escaping (Error) -> Void = { _ in }) {
        self.defaults = defaults
        self.desiredRegistration = desiredRegistration
        self.register = register
        self.unregister = unregister
        self.onError = onError
    }

    func reconcile() async {
        pending = true
        if let task {
            await task.value
            return
        }
        let newTask = Task { @MainActor in
            repeat {
                self.pending = false
                let desired = await self.desiredRegistration()
                do {
                    let registeredToken = self.defaults.string(forKey: Self.tokenKey)
                    switch desired {
                    case .unresolved:
                        break
                    case .inactive:
                        if let registeredToken {
                            try await self.unregister(registeredToken)
                            self.clearRegistration()
                        }
                    case .active(let token, let jws, let marker):
                        if let registeredToken, registeredToken != token {
                            try await self.unregister(registeredToken)
                            self.clearRegistration()
                            // The entitlement/token may have changed during the request.
                            self.pending = true
                            continue
                        }
                        if registeredToken != token || self.defaults.string(forKey: Self.markerKey) != marker {
                            try await self.register(token, jws)
                            self.defaults.set(token, forKey: Self.tokenKey)
                            self.defaults.set(marker, forKey: Self.markerKey)
                        }
                    }
                } catch {
                    // Keep the markers: a later regular reconciliation must retry.
                    self.onError(error)
                }
                if await self.desiredRegistration() != desired { self.pending = true }
            } while self.pending
            self.task = nil
        }
        task = newTask
        await newTask.value
    }

    private func clearRegistration() {
        defaults.removeObject(forKey: Self.tokenKey)
        defaults.removeObject(forKey: Self.markerKey)
    }
}
