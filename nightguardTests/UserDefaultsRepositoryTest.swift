//
//  UserDefaultsRepositoryTest.swift
//  nightguard
//
//  Created by Dirk Hermanns on 15.06.16.
//  Copyright © 2016 private. All rights reserved.
//

import XCTest

class UserDefaultsRepositoryTest : XCTestCase {

    func testLegacyTokenURLIsMigratedToCredentialStore() {
        let originalURL = UserDefaultsRepository.baseUri.value
        let originalHistory = UserDefaultsRepository.nightscoutUris.value
        let originalCredentialStore = UserDefaultsRepository.credentialStore
        let credentialStore = StubNightscoutCredentialStore()
        UserDefaultsRepository.credentialStore = credentialStore
        defer {
            UserDefaultsRepository.credentialStore = originalCredentialStore
            UserDefaultsRepository.baseUri.value = originalURL
            UserDefaultsRepository.nightscoutUris.value = originalHistory
        }

        UserDefaultsRepository.baseUri.value = "https://migration-test.example.org/nightscout?tenant=one&token=care-secret"

        XCTAssertEqual(UserDefaultsRepository.baseUri.value, "https://migration-test.example.org/nightscout?tenant=one")
        XCTAssertEqual(UserDefaultsRepository.nightscoutToken, "care-secret")
        XCTAssertFalse(UserDefaultsRepository.baseUri.value.contains("token="))
        XCTAssertEqual(
            credentialStore.token(for: URL(string: "https://migration-test.example.org/nightscout?tenant=one")!),
            "care-secret"
        )
    }

    func testLegacyTokenURLIsPreservedWhenCredentialStoreFails() {
        let originalURL = UserDefaultsRepository.baseUri.value
        let originalHistory = UserDefaultsRepository.nightscoutUris.value
        let originalCredentialStore = UserDefaultsRepository.credentialStore
        let credentialStore = StubNightscoutCredentialStore()
        credentialStore.shouldSucceed = false
        UserDefaultsRepository.credentialStore = credentialStore
        defer {
            UserDefaultsRepository.credentialStore = originalCredentialStore
            UserDefaultsRepository.baseUri.value = originalURL
            UserDefaultsRepository.nightscoutUris.value = originalHistory
        }

        let legacyURL = "https://migration-failure.example.org/nightscout?token=care-secret"
        UserDefaultsRepository.baseUri.value = legacyURL

        XCTAssertEqual(UserDefaultsRepository.baseUri.value, legacyURL)
        XCTAssertEqual(UserDefaultsRepository.nightscoutToken, "care-secret")

        credentialStore.shouldSucceed = true
        UserDefaultsRepository.parseBaseUri()

        XCTAssertEqual(UserDefaultsRepository.baseUri.value, "https://migration-failure.example.org/nightscout")
        XCTAssertEqual(UserDefaultsRepository.nightscoutToken, "care-secret")
    }

    func testLegacyURIHistoryIsOnlyCleanedAfterTokenWasStored() {
        let originalURL = UserDefaultsRepository.baseUri.value
        let originalHistory = UserDefaultsRepository.nightscoutUris.value
        let originalCredentialStore = UserDefaultsRepository.credentialStore
        let credentialStore = StubNightscoutCredentialStore()
        credentialStore.shouldSucceed = false
        UserDefaultsRepository.credentialStore = credentialStore
        defer {
            UserDefaultsRepository.credentialStore = originalCredentialStore
            UserDefaultsRepository.baseUri.value = originalURL
            UserDefaultsRepository.nightscoutUris.value = originalHistory
        }

        let legacyHistoryURL = "https://history-migration.example.org/nightscout?token=history-secret"
        UserDefaultsRepository.nightscoutUris.value = [legacyHistoryURL]
        UserDefaultsRepository.parseBaseUri()

        XCTAssertEqual(UserDefaultsRepository.nightscoutUris.value, [legacyHistoryURL])

        credentialStore.shouldSucceed = true
        UserDefaultsRepository.parseBaseUri()

        XCTAssertEqual(
            UserDefaultsRepository.nightscoutUris.value,
            ["https://history-migration.example.org/nightscout"]
        )
    }

    func testSettingAndRemovingNightscoutCredentialsUsesCredentialStore() {
        let originalURL = UserDefaultsRepository.baseUri.value
        let originalHistory = UserDefaultsRepository.nightscoutUris.value
        let originalCredentialStore = UserDefaultsRepository.credentialStore
        let credentialStore = StubNightscoutCredentialStore()
        UserDefaultsRepository.credentialStore = credentialStore
        defer {
            UserDefaultsRepository.credentialStore = originalCredentialStore
            UserDefaultsRepository.baseUri.value = originalURL
            UserDefaultsRepository.nightscoutUris.value = originalHistory
        }

        let urlWithEmbeddedToken = URL(
            string: "https://settings-token.example.org/nightscout?tenant=one&token=old-secret"
        )!
        XCTAssertTrue(
            UserDefaultsRepository.setNightscoutCredentials(
                baseURL: urlWithEmbeddedToken,
                token: "token=new-secret"
            )
        )

        let cleanURL = URL(string: "https://settings-token.example.org/nightscout?tenant=one")!
        XCTAssertEqual(UserDefaultsRepository.baseUri.value, cleanURL.absoluteString)
        XCTAssertEqual(UserDefaultsRepository.nightscoutToken, "new-secret")
        XCTAssertEqual(credentialStore.token(for: cleanURL), "new-secret")

        XCTAssertTrue(UserDefaultsRepository.setNightscoutCredentials(baseURL: cleanURL, token: ""))
        XCTAssertEqual(UserDefaultsRepository.nightscoutToken, "")
        XCTAssertNil(credentialStore.token(for: cleanURL))
    }

    override func setUp() {
        super.setUp()
        // Clear treatments before each test to ensure isolation
        UserDefaultsRepository.treatments.value = []
    }

    override func tearDown() {
        // Clean up after each test
        UserDefaultsRepository.treatments.value = []
        super.tearDown()
    }

    func testSaveUnitsWithMgdl() {
        
        UserDefaultsRepository.units.value = Units.mgdl
        
        XCTAssertEqual(UserDefaultsRepository.units.value, Units.mgdl)
    }
    
    func testSaveUnitsWithMmoll() {
        
        UserDefaultsRepository.units.value = Units.mmol
        
        XCTAssertEqual(UserDefaultsRepository.units.value, Units.mmol)
    }
    
    // Commented out - screenlockSwitchState property was removed from UserDefaultsRepository
    /*
    func testScreenLockStateIsSaved() {

        // Given
        let initialPosition : Bool = false

        // When
        UserDefaultsRepository.screenlockSwitchState.value = initialPosition
        let retrievedPosition = UserDefaultsRepository.screenlockSwitchState.value

        // Then
        XCTAssertEqual(retrievedPosition, initialPosition)
    }
    */
    
    func testSaveTreatments() {

        // Given
        var treatments : [Treatment] = []
        treatments.append(Treatment.init(id: "id0", timestamp: 0))
        treatments.append(Treatment.init(id: "id1", timestamp: 1))

        // When - Store treatments using NSKeyedArchiver for proper NSSecureCoding support
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: treatments, requiringSecureCoding: true)
        defaults?.set(encodedData, forKey: "treatments")

        // Retrieve using NSKeyedUnarchiver
        guard let data = defaults?.object(forKey: "treatments") as? Data else {
            XCTFail("Failed to retrieve treatments data from UserDefaults")
            return
        }

        guard let retrievedTreatments = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, Treatment.self, NSString.self, NSNumber.self], from: data)) as? [Treatment] else {
            XCTFail("Failed to decode treatments from data")
            return
        }

        // Then
        XCTAssertEqual(retrievedTreatments.count, 2)

        XCTAssertEqual(retrievedTreatments[0].id, "id0")
        XCTAssertEqual(retrievedTreatments[0].timestamp, 0)

        XCTAssertEqual(retrievedTreatments[1].id, "id1")
        XCTAssertEqual(retrievedTreatments[1].timestamp, 1)
    }
    
    func testTabIdentifierEnumValues() {
        XCTAssertEqual(TabIdentifier.main.rawValue, "main")
        XCTAssertEqual(TabIdentifier.alarms.rawValue, "alarms")
        XCTAssertEqual(TabIdentifier.care.rawValue, "care")
        XCTAssertEqual(TabIdentifier.duration.rawValue, "duration")
        XCTAssertEqual(TabIdentifier.stats.rawValue, "stats")
        XCTAssertEqual(TabIdentifier.prefs.rawValue, "prefs")
    }
    
    func testTabIdentifierMigrationFromInt() {
        // Test migration from old Int values
        XCTAssertEqual(TabIdentifier.fromAny(0), .main)
        XCTAssertEqual(TabIdentifier.fromAny(1), .alarms)
        XCTAssertEqual(TabIdentifier.fromAny(2), .care)
        XCTAssertEqual(TabIdentifier.fromAny(3), .duration)
        XCTAssertEqual(TabIdentifier.fromAny(4), .stats)
        XCTAssertEqual(TabIdentifier.fromAny(5), .prefs)
        
        // Test default for unknown int
        XCTAssertEqual(TabIdentifier.fromAny(99), .main)
    }
    
    func testTabIdentifierStringSerialization() {
        // Test string roundtrip
        XCTAssertEqual(TabIdentifier.fromAny("care"), .care)
        XCTAssertEqual(TabIdentifier.fromAny("stats"), .stats)
        
        // Test unknown string
        XCTAssertNil(TabIdentifier.fromAny("unknown_tab"))
    }
    
    func testTabIdentifierToAny() {
        XCTAssertEqual(TabIdentifier.care.toAny() as? String, "care")
    }
}

private final class StubNightscoutCredentialStore: NightscoutCredentialStoring {
    var shouldSucceed = true
    private var tokens: [String: String] = [:]

    func token(for serverURL: URL) -> String? {
        tokens[serverURL.absoluteString]
    }

    func setToken(_ token: String, for serverURL: URL) -> Bool {
        guard shouldSucceed else { return false }
        tokens[serverURL.absoluteString] = token
        return true
    }

    func removeToken(for serverURL: URL) -> Bool {
        guard shouldSucceed else { return false }
        tokens.removeValue(forKey: serverURL.absoluteString)
        return true
    }
}
