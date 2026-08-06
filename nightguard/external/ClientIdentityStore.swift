import Foundation
import Security

/* Stores a client certificate identity (PKCS#12) in the keychain.
   It is used to answer TLS client certificate challenges (mTLS), e.g. when
   the Nightscout server sits behind a reverse proxy that requires mutual TLS.
   The identity is shared with the watch and widget targets using the
   existing app group as keychain access group. */
class ClientIdentityStore {

    static let keychainAccessGroup = "group.de.my-wan.dhe.nightguard"

    private static let keychainQueue = DispatchQueue(label: "nightguard.client-identity-store")

    fileprivate static let identityLabel = "nightguard-client-identity"
    fileprivate static let chainCertificateLabel = "nightguard-client-identity-chain"

    enum ClientIdentityError: LocalizedError {
        case wrongPassword
        case invalidData
        case keychainError(OSStatus)
        case certificateExpired
        case certificateInvalid

        var errorDescription: String? {
            switch self {
            case .wrongPassword:
                return NSLocalizedString("The certificate password is wrong.", comment: "Client certificate wrong password error")
            case .invalidData:
                return NSLocalizedString("The file is not a valid PKCS#12 (.p12/.pfx) certificate.", comment: "Client certificate invalid file error")
            case .keychainError(let status):
                NSLog("ClientIdentityStore: keychain error (OSStatus %d)", status)
                return NSLocalizedString("The certificate could not be stored in the keychain.", comment: "Client certificate keychain error")
            case .certificateExpired:
                return NSLocalizedString("The certificate has expired.", comment: "Client certificate expired error")
            case .certificateInvalid:
                return NSLocalizedString("The certificate is not valid for client authentication.", comment: "Client certificate validation error")
            }
        }
    }


    // MARK: - Internal helpers (caller must be on keychainQueue)

    private static func _getIdentityUnsafe() -> SecIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: identityLabel,
            kSecAttrAccessGroup as String: keychainAccessGroup,
            kSecReturnRef as String: true]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let result = result, CFGetTypeID(result) == SecIdentityGetTypeID() else {
            return nil
        }
        guard let identity = result as? SecIdentity else { return nil }
        return identity
    }

    private static func _getChainCertificatesUnsafe() -> [SecCertificate]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: chainCertificateLabel,
            kSecAttrAccessGroup as String: keychainAccessGroup,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? [SecCertificate]
    }

    private static func _removeIdentityUnsafe() {
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: identityLabel,
            kSecAttrAccessGroup as String: keychainAccessGroup]
        let identityStatus = SecItemDelete(identityQuery as CFDictionary)
        if identityStatus != errSecSuccess && identityStatus != errSecItemNotFound {
            NSLog("ClientIdentityStore: failed to delete identity (OSStatus %d)", identityStatus)
        }

        let chainQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: chainCertificateLabel,
            kSecAttrAccessGroup as String: keychainAccessGroup]
        let chainStatus = SecItemDelete(chainQuery as CFDictionary)
        if chainStatus != errSecSuccess && chainStatus != errSecItemNotFound {
            NSLog("ClientIdentityStore: failed to delete chain certificates (OSStatus %d)", chainStatus)
        }
    }
    /* Imports a PKCS#12 file and persists the contained identity in the keychain.
       An already stored identity gets replaced.
       The caller should zero the p12Data after this call to prevent private key
       material from lingering in memory. */
    @discardableResult
    static func importIdentity(p12Data: Data, password: String) throws -> SecIdentity {
        // Parse PKCS#12 outside the keychain queue — SecPKCS12Import performs
        // cryptographic operations that must not block concurrent TLS handshakes.
        let options = [kSecImportExportPassphrase as String: password]
        var rawItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)

        guard status != errSecAuthFailed && status != errSecPkcs12VerifyFailure else {
            throw ClientIdentityError.wrongPassword
        }
        guard status == errSecSuccess,
              let items = rawItems as? [[String: Any]],
              let firstItem = items.first,
              let identityRef = firstItem[kSecImportItemIdentity as String] else {
            throw ClientIdentityError.invalidData
        }
        guard let identity = identityRef as? SecIdentity else {
            throw ClientIdentityError.invalidData
        }

        let certChain = firstItem[kSecImportItemCertChain as String] as? [SecCertificate]

        // Validate the certificate before persisting it in the keychain.
        // Fail-fast on expired or untrusted certificates rather than waiting
        // for the TLS handshake to fail with an opaque error.
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
              let certificate = certificate else {
            throw ClientIdentityError.certificateInvalid
        }

        // Trust evaluation — rejects certificates whose chain cannot be
        // validated. The imported certificate is temporarily added as a trust
        // anchor so that self-signed client certificates (the common mTLS case)
        // pass evaluation.
        if let trustRef = firstItem[kSecImportItemTrust as String],
           let trust = trustRef as? SecTrust {
            SecTrustSetAnchorCertificates(trust, [certificate] as CFArray)
            var trustError: CFError?
            guard SecTrustEvaluateWithError(trust, &trustError) else {
                throw ClientIdentityError.certificateInvalid
            }
        }

        // Verify the certificate has clientAuth EKU if EKU is present.
        // Per RFC 5280 §4.2.1.12: no EKU extension = valid for all purposes.
        // Only reject if EKU exists but clientAuth OID is missing.
        if let values = SecCertificateCopyValues(certificate,
                                                  [kSecOIDExtendedKeyUsage] as CFArray,
                                                  nil) as? [String: Any],
           let ekuDict = values[kSecOIDExtendedKeyUsage as String] as? [String: Any],
           let ekuValues = ekuDict[kSecPropertyKeyValue as String] as? [String],
           !ekuValues.isEmpty {
            guard ekuValues.contains("1.3.6.1.5.5.7.3.2") else {
                throw ClientIdentityError.certificateInvalid
            }
        }

        // Check expiry via the system API, with hand-rolled DER parser as
        // fallback for certificates the system API cannot parse.
        let expired: Bool = {
            var copyError: Unmanaged<CFError>?
            if let values = SecCertificateCopyValues(certificate,
                                                      [kSecOIDX509V1ValidityNotAfter] as CFArray,
                                                      &copyError) as? [String: Any],
               let notAfterDict = values[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
               let notAfterNumber = notAfterDict[kSecPropertyKeyValue as String] as? NSNumber {
                return Date() >= Date(timeIntervalSinceReferenceDate: notAfterNumber.doubleValue)
            }
            // Fall back to hand-rolled DER parser.
            let derData = SecCertificateCopyData(certificate) as Data
            guard let expiry = parseExpiryDate(from: derData) else { return true }
            return Date() >= expiry
        }()
        guard !expired else {
            throw ClientIdentityError.certificateExpired
        }

        // Atomically update the keychain with the extracted identity.
        try keychainQueue.sync {
            // Keep a reference to any previously stored identity so we can
            // remove it only after the new one is safely in the keychain.
            // A failed import must never leave the user without a certificate.
            let previousIdentity = _getIdentityUnsafe()

            let addIdentityQuery: [String: Any] = [
                kSecValueRef as String: identity,
                kSecAttrLabel as String: identityLabel,
                kSecAttrAccessGroup as String: keychainAccessGroup,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock] // Removing ThisDeviceOnly allows the certificate to survive encrypted backups. The certificate is device-specific and invalid on a new device anyway.
            let addStatus = SecItemAdd(addIdentityQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
                throw ClientIdentityError.keychainError(addStatus)
            }

            // Remove the previous identity, but only if a brand-new item was
            // added. On errSecDuplicateItem the desired cert is already present
            // and must not be deleted.
            if addStatus == errSecSuccess, let previousIdentity = previousIdentity {
                let deleteOldQuery: [String: Any] = [
                    kSecClass as String: kSecClassIdentity,
                    kSecAttrAccessGroup as String: keychainAccessGroup,
                    kSecMatchItemList as String: [previousIdentity]]
                SecItemDelete(deleteOldQuery as CFDictionary)
            }

            // Replace the certificate chain: drop the previous intermediates,
            // then store the new ones.
            let chainDeleteQuery: [String: Any] = [
                kSecClass as String: kSecClassCertificate,
                kSecAttrLabel as String: chainCertificateLabel,
                kSecAttrAccessGroup as String: keychainAccessGroup]
            SecItemDelete(chainDeleteQuery as CFDictionary)

            if let certChain = certChain, certChain.count > 1 {
                for (index, certificate) in certChain.dropFirst().enumerated() {
                    let addCertificateQuery: [String: Any] = [
                        kSecValueRef as String: certificate,
                        kSecAttrLabel as String: chainCertificateLabel,
                        kSecAttrAccessGroup as String: keychainAccessGroup,
                        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
                    let chainStatus = SecItemAdd(addCertificateQuery as CFDictionary, nil)
                    if chainStatus != errSecSuccess && chainStatus != errSecDuplicateItem {
                        NSLog("ClientIdentityStore: failed to add chain certificate %d (OSStatus %d)", index, chainStatus)
                    }
                }
            }

            return identity
        }
    }

    /* Returns the stored identity or nil if no client certificate is configured. */
    static func getIdentity() -> SecIdentity? {
        keychainQueue.sync {
            _getIdentityUnsafe()
        }
    }

    /* Returns a credential for answering a TLS client certificate challenge
       or nil if no client certificate is configured. */
    static func getCredential() -> URLCredential? {
        keychainQueue.sync {
            guard let identity = _getIdentityUnsafe() else {
                return nil
            }
            return URLCredential(identity: identity, certificates: _getChainCertificatesUnsafe(), persistence: .none)
        }
    }

    /* Returns the common name of the stored certificate or nil if no client certificate is configured. */
    static func getCommonName() -> String? {
        keychainQueue.sync {
            guard let identity = _getIdentityUnsafe() else {
                return nil
            }
            var certificate: SecCertificate?
            guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate = certificate else {
                return nil
            }
            return SecCertificateCopySubjectSummary(certificate) as String?
        }
    }

    /* Returns the notAfter expiry date of the stored certificate, or nil if no
       client certificate is configured. The UI uses this to warn the user
       before the certificate expires. */
    static func getExpiryDate() -> Date? {
        keychainQueue.sync {
            guard let identity = _getIdentityUnsafe() else { return nil }
            var certificate: SecCertificate?
            guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
                  let certificate = certificate else {
                return nil
            }
            let derData = SecCertificateCopyData(certificate) as Data
            return parseExpiryDate(from: derData)
        }
    }

    // MARK: - X.509 validity parsing (minimal DER)

    /* Parses the notAfter date out of a DER-encoded X.509 certificate. */
    private static func parseExpiryDate(from derData: Data) -> Date? {
        func readTime(_ tag: UInt8, _ value: [UInt8]) -> Date? {
            guard let str = String(bytes: value, encoding: .ascii) else { return nil }
            func digits(_ from: Int, _ count: Int) -> Int {
                let s = str.index(str.startIndex, offsetBy: from)
                let e = str.index(s, offsetBy: count)
                return Int(str[s..<e]) ?? 0
            }
            var c = DateComponents()
            c.timeZone = TimeZone(identifier: "UTC")
            if tag == 0x17, str.count >= 11 {        // UTCTime: YYMMDDHHmmssZ
                let yy = digits(0, 2)
                c.year = yy >= 50 ? 1900 + yy : 2000 + yy
                c.month = digits(2, 2); c.day = digits(4, 2)
                c.hour = digits(6, 2); c.minute = digits(8, 2)
                c.second = str.count >= 13 ? digits(10, 2) : 0
            } else if tag == 0x18, str.count >= 13 { // GeneralizedTime: YYYYMMDDHHmmssZ
                c.year = digits(0, 4)
                c.month = digits(4, 2); c.day = digits(6, 2)
                c.hour = digits(8, 2); c.minute = digits(10, 2)
                c.second = str.count >= 15 ? digits(12, 2) : 0
            } else {
                return nil
            }
            return Calendar(identifier: .gregorian).date(from: c)
        }

        let bytes = [UInt8](derData)
        guard let cert = derTLV(bytes), cert.tag == 0x30,                 // Certificate
              let tbs = derTLV(cert.value), tbs.tag == 0x30 else {        // TBSCertificate
            return nil
        }
        // Walk TBSCertificate fields in order, skipping those before Validity.
        guard var node = derTLV(tbs.value) else { return nil }
        if node.tag == 0xA0 {                                             // optional [0] version
            guard let next = derTLV(node.rest) else { return nil }
            node = next
        }
        // node is now serialNumber; skip it, then signature alg, then issuer.
        guard let sigAlg = derTLV(node.rest),
              let issuer = derTLV(sigAlg.rest),
              let validity = derTLV(issuer.rest), validity.tag == 0x30,
              let notBefore = derTLV(validity.value),
              let notAfter = derTLV(notBefore.rest) else {
            return nil
        }
        return readTime(notAfter.tag, notAfter.value)
    }

    /* Uses hand-rolled minimal DER parser for expiry date only.
       Production hardening: prefer SecCertificateCopyValues with
       kSecOIDX509V1ValidityNotAfter. */
    private static func derTLV(_ bytes: [UInt8]) -> (tag: UInt8, value: [UInt8], rest: [UInt8])? {
        var i = 0
        guard bytes.count >= 2 else { return nil }
        let tag = bytes[i]; i += 1
        let lengthByte = bytes[i]; i += 1
        let length: Int
        if lengthByte < 0x80 {
            length = Int(lengthByte)
        } else {
            let n = Int(lengthByte & 0x7F)
            guard n > 0, n <= 8 else { return nil }
            var len = 0
            for _ in 0..<n {
                guard i < bytes.count else { return nil }
                guard len <= (Int.max >> 8) else { return nil }
                len = (len << 8) | Int(bytes[i])
                i += 1
            }
            length = len
        }
        guard length <= 1024 * 1024 else { return nil }
        guard i + length <= bytes.count else { return nil }
        let value = Array(bytes[i..<(i + length)])
        let rest = Array(bytes[(i + length)...])
        return (tag, value, rest)
    }

    /* Removes the stored identity and its certificate chain from the keychain. */
    static func removeIdentity() {
        keychainQueue.sync {
            _removeIdentityUnsafe()
        }
    }

}
