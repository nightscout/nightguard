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


final class BoundedLogFileTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("logs.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testHistorySurvivesRestartAndKeepsNewestEntries() throws {
        let store = BoundedLogFile<String>(fileURL: fileURL, maxEntries: 3, maxBytes: 1024)
        for index in 0..<10 { store.append("entry-\(index)") }
        XCTAssertEqual(store.snapshot(), ["entry-7", "entry-8", "entry-9"])
        let restored = BoundedLogFile<String>(fileURL: fileURL, maxEntries: 3, maxBytes: 1024)
        XCTAssertEqual(restored.snapshot(), store.snapshot())
    }

    func testEncodedByteLimitIncludesJSONEscapingAndUnicode() throws {
        let store = BoundedLogFile<String>(fileURL: fileURL, maxEntries: 500, maxBytes: 256)
        for _ in 0..<20 { store.append(String(repeating: "😀\"\n", count: 10)) }
        let entries = store.snapshot()
        XCTAssertFalse(entries.isEmpty)
        XCTAssertLessThan(entries.count, 20)
        let data = try Data(contentsOf: fileURL)
        XCTAssertLessThanOrEqual(data.count, 256)
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: data), entries)
    }

    func testMessageLimitPreservesValidUTF8AndMarksTruncation() {
        let message = String(repeating: "😀é", count: 2000)
        let bounded = LogStorage.boundedMessage(message)
        XCTAssertLessThanOrEqual(bounded.utf8.count, 4096)
        XCTAssertTrue(bounded.hasSuffix("[truncated]"))
        XCTAssertFalse(bounded.contains("�"))
        XCTAssertEqual(LogStorage.boundedMessage("short"), "short")
    }

    func testOversizedAndCorruptFilesAreDiscarded() throws {
        for data in [Data(repeating: 65, count: 1025), Data("invalid JSON".utf8)] {
            try data.write(to: fileURL)
            let store = BoundedLogFile<String>(fileURL: fileURL, maxEntries: 3, maxBytes: 1024)
            XCTAssertEqual(store.snapshot(), [])
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
            store.append("recovered")
            XCTAssertEqual(store.snapshot(), ["recovered"])
        }
    }

    func testClearCannotBeUndoneByQueuedWrites() {
        let store = BoundedLogFile<String>(fileURL: fileURL, maxEntries: 500, maxBytes: 4096)
        for index in 0..<100 { store.append("entry-\(index)") }
        store.clear()
        XCTAssertEqual(store.snapshot(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        store.append("after-clear")
        XCTAssertEqual(store.snapshot(), ["after-clear"])
    }

    func testConcurrentLoggingAndFailedWritesRemainUsable() throws {
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: blocker)
        let store = BoundedLogFile<String>(fileURL: blocker.appendingPathComponent("logs.json"), maxEntries: 10, maxBytes: 1024)
        DispatchQueue.concurrentPerform(iterations: 30) { store.append("entry-\($0)") }
        XCTAssertEqual(store.snapshot().count, 10)
        store.clear()
        XCTAssertTrue(store.snapshot().isEmpty)
    }

    func testLegacyCleanupPreservesOtherPreferencesAndIsRepeatable() {
        let suite = "BoundedLogFileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data(repeating: 1, count: 128 * 1024), forKey: "AppLogger.persistedLogs")
        defaults.set(["old"], forKey: "BackgroundRefreshLogger.sharedLogs")
        defaults.set("configured-server", forKey: "baseUri")
        defaults.set(Data([1, 2, 3]), forKey: "nightscoutEntries")
        for _ in 0..<2 { LogStorage.removeLegacyLogs(from: defaults) }
        XCTAssertNil(defaults.object(forKey: "AppLogger.persistedLogs"))
        XCTAssertNil(defaults.object(forKey: "BackgroundRefreshLogger.sharedLogs"))
        XCTAssertEqual(defaults.string(forKey: "baseUri"), "configured-server")
        XCTAssertEqual(defaults.data(forKey: "nightscoutEntries"), Data([1, 2, 3]))
    }

    func testCallbacksPublishOnMainInClearOrder() {
        let completed = expectation(description: "ordered snapshots")
        let store = BoundedLogFile<String>(fileURL: fileURL, maxEntries: 3, maxBytes: 1024)
        var snapshots: [[String]] = []
        store.append("before") { entries in
            XCTAssertTrue(Thread.isMainThread)
            snapshots.append(entries)
        }
        store.clear { entries in
            XCTAssertTrue(Thread.isMainThread)
            snapshots.append(entries)
        }
        store.append("after") { entries in
            XCTAssertTrue(Thread.isMainThread)
            snapshots.append(entries)
            XCTAssertEqual(snapshots, [["before"], [], ["after"]])
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
    }
}
