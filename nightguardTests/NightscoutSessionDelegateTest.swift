import XCTest

class NightscoutSessionDelegateTest: XCTestCase {

    var delegate: NightscoutSessionDelegate!
    var savedBaseUri: String = ""

    override func setUp() {
        super.setUp()
        delegate = NightscoutSessionDelegate()

        // Save current baseUri so we can restore it in tearDown
        savedBaseUri = UserDefaultsRepository.baseUri.value
    }

    override func tearDown() {
        // Restore original baseUri — prevents test leakage
        UserDefaultsRepository.baseUri.value = savedBaseUri
        delegate = nil
        super.tearDown()
    }

    /// The delegate must NOT present a client certificate when the challenge host
    /// does not match the configured Nightscout host.
    func testDoesNotPresentCredentialForForeignHost() {

        UserDefaultsRepository.baseUri.value = "https://nightscout.example.com"

        let expectation = self.expectation(description: "completionHandler called")
        let protectionSpace = MockProtectionSpace(host: "attacker.example.com", authMethod: NSURLAuthenticationMethodClientCertificate)
        let challenge = MockChallenge(protectionSpace: protectionSpace)

        delegate.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential, "Credential must not be presented to a foreign host")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    /// The delegate must NOT present a client certificate when the host matches
    /// but the port differs (e.g., mTLS on port 8443 vs non-mTLS on 443).
    func testDoesNotPresentCredentialForDifferentPort() {

        // Configured URL on port 8443 (the mTLS port)
        UserDefaultsRepository.baseUri.value = "https://nightscout.example.com:8443"

        let expectation = self.expectation(description: "completionHandler called")
        // Challenge arrives on port 443 (non-mTLS) — same host, different port
        let protectionSpace = MockProtectionSpace(host: "nightscout.example.com", port: 443, authMethod: NSURLAuthenticationMethodClientCertificate)
        let challenge = MockChallenge(protectionSpace: protectionSpace)

        delegate.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential, "Credential must not be presented on a different port")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    /// The delegate must present a client certificate when the challenge host
    /// matches the configured Nightscout host and a credential is available.
    /// Note: this test requires a valid client certificate in the keychain
    /// to actually exercise the credential path; without one it falls through
    /// to .performDefaultHandling (which is also correct).
    func testFallsThroughWhenNoCertificateConfigured() {

        UserDefaultsRepository.baseUri.value = "https://nightscout.example.com"
        ClientIdentityStore.removeIdentity()

        let expectation = self.expectation(description: "completionHandler called")
        let protectionSpace = MockProtectionSpace(host: "nightscout.example.com", authMethod: NSURLAuthenticationMethodClientCertificate)
        let challenge = MockChallenge(protectionSpace: protectionSpace)

        delegate.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            // Without a cert: .performDefaultHandling (system handles)
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    /// The delegate must fall through to default handling for server trust challenges.
    func testFallsThroughForServerTrustChallenge() {

        UserDefaultsRepository.baseUri.value = "https://nightscout.example.com"

        let expectation = self.expectation(description: "completionHandler called")
        let protectionSpace = MockProtectionSpace(host: "nightscout.example.com", authMethod: NSURLAuthenticationMethodServerTrust)
        let challenge = MockChallenge(protectionSpace: protectionSpace)

        delegate.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    /// The delegate must fall through when no baseUri is configured.
    func testFallsThroughWhenNoBaseUriConfigured() {

        UserDefaultsRepository.baseUri.value = ""

        let expectation = self.expectation(description: "completionHandler called")
        let protectionSpace = MockProtectionSpace(host: "nightscout.example.com", authMethod: NSURLAuthenticationMethodClientCertificate)
        let challenge = MockChallenge(protectionSpace: protectionSpace)

        delegate.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}

// MARK: - Minimal mock for URLAuthenticationChallenge

final class MockProtectionSpace: URLProtectionSpace {
    init(host: String, port: Int = 0, authMethod: String) {
        super.init(host: host, port: port, protocol: nil, realm: nil, authenticationMethod: authMethod)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

final class MockChallenge: URLAuthenticationChallenge {
    init(protectionSpace: URLProtectionSpace) {
        super.init(protectionSpace: protectionSpace, proposedCredential: nil,
                   previousFailureCount: 0, failureResponse: nil,
                   error: nil, sender: MockChallengeSender())
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

final class MockChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func start(_ challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}
