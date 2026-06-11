//
//  MaxBackendAppCheckService.swift
//  nightguard
//

import Foundation

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

final class MaxBackendAppCheckService {
    static let shared = MaxBackendAppCheckService()

    private init() {}

    func token() async -> String? {
        #if canImport(FirebaseAppCheck)
        return await withCheckedContinuation { continuation in
            AppCheck.appCheck().token(forcingRefresh: false) { token, error in
                if let error = error {
                    AppLogger.singleton.warning("Firebase App Check token unavailable: \(error.localizedDescription)", category: .backgroundUpdates)
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: token?.token)
            }
        }
        #else
        return nil
        #endif
    }
}
