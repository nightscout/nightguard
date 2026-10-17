import XCTest

@MainActor
final class MaxSubscriptionTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var date = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        suite = "MaxSubscriptionTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func transaction(id: String = "1", lifetime: TimeInterval = 3600,
                             revoked: Bool = false, upgraded: Bool = false,
                             productID: String = MaxSubscriptionTransaction.productID) -> MaxSubscriptionTransaction {
        MaxSubscriptionTransaction(productID: productID, transactionID: id,
                                   expiresAt: date.addingTimeInterval(lifetime),
                                   revoked: revoked, upgraded: upgraded, jws: "test-jws-\(id)")
    }

    func testLegacyActiveFlagCannotGrantAccessAfterRestart() async {
        defaults.set(true, forKey: MaxSubscriptionTransaction.productID)
        let expired = transaction(lifetime: -1)
        let monitor = MaxSubscriptionMonitor(defaults: defaults, now: { self.date }, readTransactions: { [expired] })
        XCTAssertFalse(monitor.isActive)
        XCTAssertFalse(monitor.hasResolvedStatus)
        await monitor.refresh()
        XCTAssertTrue(monitor.hasResolvedStatus)
        XCTAssertFalse(monitor.isActive)
        XCTAssertNil(monitor.currentJWS)
        XCTAssertNil(MaxSubscriptionCache.load(from: defaults))
    }

    func testVerifiedCacheSurvivesOfflineRestartButNeverExtendsExpiry() async {
        let active = transaction()
        let monitor = MaxSubscriptionMonitor(defaults: defaults, now: { self.date }, readTransactions: { [active] })
        await monitor.refresh()
        let restarted = MaxSubscriptionMonitor(defaults: defaults, now: { self.date }, readTransactions: { throw TestError.offline })
        XCTAssertTrue(restarted.isActive)
        await restarted.refresh()
        XCTAssertTrue(restarted.isActive)
        XCTAssertTrue(restarted.lastCheckFailed)
        XCTAssertNil(restarted.currentJWS, "A cache cannot fabricate a signed transaction")
        date = date.addingTimeInterval(3600)
        await restarted.refresh()
        XCTAssertFalse(restarted.isActive)
        XCTAssertTrue(restarted.hasResolvedStatus)
    }

    func testEmptyEntitlementsOverrideEvenUnexpiredCache() async {
        var results = [transaction()]
        let monitor = MaxSubscriptionMonitor(defaults: defaults, now: { self.date }, readTransactions: { results })
        await monitor.refresh()
        XCTAssertTrue(monitor.isActive)
        results = []
        await monitor.refresh(force: true)
        XCTAssertFalse(monitor.isActive)
        XCTAssertNil(monitor.currentJWS)
        XCTAssertNil(MaxSubscriptionCache.load(from: defaults))
    }

    func testRevokedUpgradedOtherProductAndMissingExpiryDoNotGrantMax() async {
        let candidates = [transaction(revoked: true), transaction(upgraded: true),
                          transaction(productID: "app.hermanns.nightguard.pro"),
                          MaxSubscriptionTransaction(productID: MaxSubscriptionTransaction.productID,
                                                     transactionID: "missing", expiresAt: nil,
                                                     revoked: false, upgraded: false, jws: "test")]
        for candidate in candidates {
            let monitor = MaxSubscriptionMonitor(defaults: defaults, now: { self.date }, readTransactions: { [candidate] })
            await monitor.refresh()
            XCTAssertFalse(monitor.isActive)
            XCTAssertNil(monitor.currentJWS)
        }
    }

    func testForegroundChecksAreThrottledAndExpiryIsReevaluated() async {
        var reads = 0
        let active = transaction(lifetime: 600)
        let monitor = MaxSubscriptionMonitor(defaults: defaults, now: { self.date }, readTransactions: {
            reads += 1
            return [active]
        })
        await monitor.refresh()
        for _ in 0..<10 {
            date = date.addingTimeInterval(60)
            await monitor.refresh()
        }
        XCTAssertEqual(reads, 1)
        XCTAssertFalse(monitor.isActive)
        XCTAssertNil(monitor.currentJWS)
        date = date.addingTimeInterval(300)
        await monitor.refresh()
        XCTAssertEqual(reads, 2)
    }

    func testRenewalUpdatesSignedTransactionWhileAccessStaysActive() async {
        var results = [transaction()]
        var refreshes = 0
        let monitor = MaxSubscriptionMonitor(defaults: defaults, now: { self.date },
                                             readTransactions: { results }, didRefresh: { refreshes += 1 })
        await monitor.refresh()
        results.append(transaction(id: "2", lifetime: 7200))
        await monitor.refresh(force: true)
        XCTAssertTrue(monitor.isActive)
        XCTAssertEqual(monitor.currentJWS, "test-jws-2")
        XCTAssertEqual(MaxSubscriptionCache.load(from: defaults)?.transactionID, "2")
        XCTAssertEqual(refreshes, 2)
    }

    func testInitialVerificationFailureDoesNotResolveAsExpired() async {
        let monitor = MaxSubscriptionMonitor(defaults: defaults, readTransactions: { throw TestError.offline })
        await monitor.refresh()
        XCTAssertFalse(monitor.hasResolvedStatus)
        XCTAssertFalse(monitor.isActive)
        XCTAssertTrue(monitor.lastCheckFailed)
    }

    func testUpdateDuringEnumerationRunsOneFreshPass() async {
        var continuation: CheckedContinuation<[MaxSubscriptionTransaction], Error>?
        let started = expectation(description: "first StoreKit enumeration")
        var reads = 0
        let renewed = transaction(id: "2")
        let monitor = MaxSubscriptionMonitor(defaults: defaults, now: { self.date }, readTransactions: {
            reads += 1
            if reads == 1 {
                return try await withCheckedThrowingContinuation {
                    continuation = $0
                    started.fulfill()
                }
            }
            return [renewed]
        })
        let first = Task { await monitor.refresh() }
        await fulfillment(of: [started], timeout: 2)
        let update = Task { await monitor.refresh(force: true) }
        await Task.yield()
        continuation?.resume(returning: [])
        await first.value
        await update.value
        XCTAssertEqual(reads, 2)
        XCTAssertEqual(monitor.currentJWS, renewed.jws)
    }

    func testFailedUnregistrationRetainsMarkersAndRetries() async {
        defaults.set("test-token", forKey: MaxPushRegistrationCoordinator.tokenKey)
        defaults.set("test-marker", forKey: MaxPushRegistrationCoordinator.markerKey)
        var attempts = 0
        let coordinator = MaxPushRegistrationCoordinator(defaults: defaults, desiredRegistration: { .inactive },
            register: { _, _ in XCTFail("Unexpected registration") }, unregister: { _ in
                attempts += 1
                if attempts == 1 { throw TestError.offline }
            })
        await coordinator.reconcile()
        XCTAssertEqual(defaults.string(forKey: MaxPushRegistrationCoordinator.tokenKey), "test-token")
        XCTAssertEqual(defaults.string(forKey: MaxPushRegistrationCoordinator.markerKey), "test-marker")
        await coordinator.reconcile()
        XCTAssertEqual(attempts, 2)
        XCTAssertNil(defaults.string(forKey: MaxPushRegistrationCoordinator.tokenKey))
        XCTAssertNil(defaults.string(forKey: MaxPushRegistrationCoordinator.markerKey))
    }

    func testPendingInitialCheckDoesNotUnregister() async {
        defaults.set("test-token", forKey: MaxPushRegistrationCoordinator.tokenKey)
        let coordinator = MaxPushRegistrationCoordinator(defaults: defaults, desiredRegistration: { .unresolved },
            register: { _, _ in XCTFail("Unexpected registration") },
            unregister: { _ in XCTFail("Must wait for initial check") })
        await coordinator.reconcile()
        XCTAssertEqual(defaults.string(forKey: MaxPushRegistrationCoordinator.tokenKey), "test-token")
    }

    func testRenewalRegistersNewTransactionWithoutDuplicatingUnchangedRegistration() async {
        var desired = MaxPushRegistration.active(token: "test-token", jws: "test-jws-1", marker: "1")
        var sent: [String] = []
        let coordinator = MaxPushRegistrationCoordinator(defaults: defaults, desiredRegistration: { desired },
            register: { _, jws in sent.append(jws) }, unregister: { _ in XCTFail("Unexpected unregistration") })
        await coordinator.reconcile()
        await coordinator.reconcile()
        desired = .active(token: "test-token", jws: "test-jws-2", marker: "2")
        await coordinator.reconcile()
        XCTAssertEqual(sent, ["test-jws-1", "test-jws-2"])
    }

    func testExpiryDuringRegistrationIsReconciledAfterRequestFinishes() async {
        var desired = MaxPushRegistration.active(token: "test-token", jws: "test-jws", marker: "1")
        var events: [String] = []
        let coordinator = MaxPushRegistrationCoordinator(defaults: defaults, desiredRegistration: { desired },
            register: { _, _ in
                events.append("register")
                desired = .inactive
            }, unregister: { _ in events.append("unregister") })
        await coordinator.reconcile()
        XCTAssertEqual(events, ["register", "unregister"])
        XCTAssertNil(defaults.string(forKey: MaxPushRegistrationCoordinator.tokenKey))
    }

    func testProReceiptCannotOverwriteMaxAndWatchFollowsCombinedAccess() async {
        let previousWatchAccess = UserDefaultsRepository.watchProAccessAvailable.value
        defer { UserDefaultsRepository.watchProAccessAvailable.value = previousWatchAccess }
        var maxTransactions = [transaction()]
        var proActive = false
        let manager = PurchaseManager(defaults: defaults, now: { self.date },
            readMaxTransactions: { maxTransactions }, proValidation: { completion in completion(proActive) })

        let first = expectation(description: "Max active and Pro receipt inactive")
        manager.validateReceipt { _ in first.fulfill() }
        await fulfillment(of: [first], timeout: 10)
        XCTAssertTrue(manager.isMaxAccessAvailable)
        XCTAssertFalse(manager.isProAccessAvailable)
        XCTAssertTrue(manager.hasProFeatureAccess)
        XCTAssertTrue(UserDefaultsRepository.watchProAccessAvailable.value)

        maxTransactions = []
        proActive = true
        let second = expectation(description: "Max expires while Pro remains active")
        manager.validateReceipt { _ in second.fulfill() }
        await fulfillment(of: [second], timeout: 10)
        XCTAssertFalse(manager.isMaxAccessAvailable)
        XCTAssertTrue(manager.hasProFeatureAccess)
        XCTAssertTrue(UserDefaultsRepository.watchProAccessAvailable.value)

        proActive = false
        let third = expectation(description: "Both subscriptions expired")
        manager.validateReceipt { _ in third.fulfill() }
        await fulfillment(of: [third], timeout: 10)
        XCTAssertFalse(manager.hasProFeatureAccess)
        XCTAssertFalse(UserDefaultsRepository.watchProAccessAvailable.value)
    }

    private enum TestError: Error { case offline }
}
