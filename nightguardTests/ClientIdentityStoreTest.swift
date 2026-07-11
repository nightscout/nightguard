import XCTest

class ClientIdentityStoreTest: XCTestCase {

    // self-signed test certificate (CN=nightguard-test), created with:
    // openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes -subj "/CN=nightguard-test"
    // openssl pkcs12 -export -legacy -out test.p12 -inkey key.pem -in cert.pem -passout pass:test1234 -name nightguard-test

    // chain certificate (leaf signed by intermediate CA), created with:
    // openssl req -x509 -newkey rsa:2048 -keyout ca-key.pem -out ca.pem -days 3650 -nodes -subj "/CN=nightguard-test-ca"
    // openssl req -new -newkey rsa:2048 -keyout leaf-key.pem -out leaf.csr -nodes -subj "/CN=nightguard-test-chain"
    // openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out leaf.pem -days 3650
    // openssl pkcs12 -export -legacy -out chain.p12 -inkey leaf-key.pem -in leaf.pem -certfile ca.pem -passout pass:chain1234 -name nightguard-test-chain
    fileprivate let chainPassword = "chain1234"
    fileprivate let p12Password = "test1234"
    fileprivate let chainBase64 =
        "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"
    fileprivate let p12Base64 =
        "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"

    override func setUp() {
        super.setUp()
        ClientIdentityStore.removeIdentity()
    }

    override func tearDown() {
        ClientIdentityStore.removeIdentity()
        super.tearDown()
    }

    func testImportAndRetrieveIdentity() throws {

        let p12Data = try XCTUnwrap(Data(base64Encoded: p12Base64))

        try ClientIdentityStore.importIdentity(p12Data: p12Data, password: p12Password)

        XCTAssertNotNil(ClientIdentityStore.getIdentity())
        XCTAssertNotNil(ClientIdentityStore.getCredential())
        XCTAssertEqual(ClientIdentityStore.getCommonName(), "nightguard-test")
    }

    func testImportWithWrongPasswordFails() throws {

        let p12Data = try XCTUnwrap(Data(base64Encoded: p12Base64))

        XCTAssertThrowsError(try ClientIdentityStore.importIdentity(p12Data: p12Data, password: "wrongpassword"))
        XCTAssertNil(ClientIdentityStore.getIdentity())
    }

    func testImportWithInvalidDataFails() {

        XCTAssertThrowsError(try ClientIdentityStore.importIdentity(p12Data: Data([0x00, 0x01, 0x02]), password: p12Password))
        XCTAssertNil(ClientIdentityStore.getIdentity())
    }

    func testRemoveIdentity() throws {

        let p12Data = try XCTUnwrap(Data(base64Encoded: p12Base64))
        try ClientIdentityStore.importIdentity(p12Data: p12Data, password: p12Password)

        ClientIdentityStore.removeIdentity()

        XCTAssertNil(ClientIdentityStore.getIdentity())
        XCTAssertNil(ClientIdentityStore.getCredential())
        XCTAssertNil(ClientIdentityStore.getCommonName())
    }

    func testReimportReplacesPreviousIdentity() throws {

        let p12Data = try XCTUnwrap(Data(base64Encoded: p12Base64))

        // First import
        try ClientIdentityStore.importIdentity(p12Data: p12Data, password: p12Password)
        let firstCommonName = ClientIdentityStore.getCommonName()
        XCTAssertEqual(firstCommonName, "nightguard-test")

        // Import a different cert (chain cert) — should replace
        let chainData = try XCTUnwrap(Data(base64Encoded: chainBase64))
        try ClientIdentityStore.importIdentity(p12Data: chainData, password: chainPassword)

        // Verify the identity was replaced, not duplicated
        let secondCommonName = ClientIdentityStore.getCommonName()
        XCTAssertEqual(secondCommonName, "nightguard-test-chain")
        XCTAssertNotEqual(firstCommonName, secondCommonName)
        XCTAssertNotNil(ClientIdentityStore.getCredential())

        // Verify only one identity exists (old one was truly replaced, not duplicated)
        // Re-import the original cert and confirm it replaces again
        try ClientIdentityStore.importIdentity(p12Data: p12Data, password: p12Password)
        let thirdCommonName = ClientIdentityStore.getCommonName()
        XCTAssertEqual(thirdCommonName, "nightguard-test", "Re-import of original cert should replace the chain cert")
        XCTAssertNotEqual(secondCommonName, thirdCommonName)
    }

    func testChainCertificateImport() throws {

        let chainData = try XCTUnwrap(Data(base64Encoded: chainBase64))
        try ClientIdentityStore.importIdentity(p12Data: chainData, password: chainPassword)

        // Verify chain cert is stored and retrievable
        XCTAssertNotNil(ClientIdentityStore.getIdentity())
        XCTAssertEqual(ClientIdentityStore.getCommonName(), "nightguard-test-chain")

        // Verify the credential includes chain certificates
        let credential = ClientIdentityStore.getCredential()
        XCTAssertNotNil(credential)
        // With a leaf + CA chain, certificates array should have at least 2 entries
        if let certs = credential?.certificates {
            XCTAssertGreaterThanOrEqual(certs.count, 2, "Chain certificate credential should include intermediate CA cert")
        }
    }

    func testGetExpiryDateReturnsDate() throws {

        let p12Data = try XCTUnwrap(Data(base64Encoded: p12Base64))
        try ClientIdentityStore.importIdentity(p12Data: p12Data, password: p12Password)

        let expiryDate = ClientIdentityStore.getExpiryDate()
        XCTAssertNotNil(expiryDate, "getExpiryDate should return a date for a valid certificate")

        if let expiry = expiryDate {
            // Cert was created with -days 3650, so it should expire far in the future
            let now = Date()
            XCTAssertGreaterThan(expiry, now, "Certificate should not be expired (notAfter should be in the future)")
        }
    }

    func testGetIdentityReturnsNilIfNotConfigured() {

        XCTAssertNil(ClientIdentityStore.getIdentity())
        XCTAssertNil(ClientIdentityStore.getCredential())
    }
}
