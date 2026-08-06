import Foundation

/* Answers TLS client certificate challenges (mTLS) with the identity from the
   ClientIdentityStore. All other challenges are handled by the system as before. */
class NightscoutSessionDelegate: NSObject, URLSessionDelegate {

    private static let delegate = NightscoutSessionDelegate()
    /* Session that is used for all nightscout requests. */
    static let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Bind the client certificate to the configured Nightscout host and port only,
        // so the credential is never offered to an unrelated server. Both URL.host
        // and protectionSpace.host use punycode for IDN domains, so comparison is safe.
        let configuredURL = URL(string: UserDefaultsRepository.baseUri.value)
        let configuredHost = configuredURL?.host?.lowercased()
        let configuredPort = configuredURL?.port ?? 443
        let challengePort = challenge.protectionSpace.port == 0 ? 443 : challenge.protectionSpace.port
        guard let configuredHost = configuredHost,
              challenge.protectionSpace.host.lowercased() == configuredHost,
              challengePort == configuredPort,
              let credential = ClientIdentityStore.getCredential() else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, credential)
    }
}
