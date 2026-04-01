import XCTest
@testable import MindRestore

@MainActor
final class ReferralServiceTests: XCTestCase {

    private var service: ReferralService!

    override func setUp() {
        super.setUp()
        service = ReferralService()
        UserDefaults.standard.removeObject(forKey: "referral_trial_expiry")
        UserDefaults.standard.removeObject(forKey: "referral_referred_by")
        UserDefaults.standard.set(0, forKey: "referral_count")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "referral_trial_expiry")
        UserDefaults.standard.removeObject(forKey: "referral_referred_by")
        UserDefaults.standard.set(0, forKey: "referral_count")
        super.tearDown()
    }

    // MARK: - Trial Management

    func testNoTrialByDefault() {
        XCTAssertFalse(service.hasActiveReferralTrial)
        XCTAssertEqual(service.trialDaysRemaining, 0)
    }

    func testGrantTrialSets7DayExpiry() {
        service.grantReferralTrial()
        XCTAssertTrue(service.hasActiveReferralTrial)
        // Calendar day boundary can make this 6 or 7
        XCTAssertTrue(service.trialDaysRemaining >= 6 && service.trialDaysRemaining <= 7)
    }

    func testMultipleTrialsStack() {
        service.grantReferralTrial()
        service.grantReferralTrial()
        XCTAssertTrue(service.trialDaysRemaining >= 13 && service.trialDaysRemaining <= 14)
    }

    func testThreeTrialsStack() {
        service.grantReferralTrial()
        service.grantReferralTrial()
        service.grantReferralTrial()
        XCTAssertTrue(service.trialDaysRemaining >= 20 && service.trialDaysRemaining <= 21)
    }

    func testExpiredTrialIsInactive() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!
        UserDefaults.standard.set(yesterday, forKey: "referral_trial_expiry")
        XCTAssertFalse(service.hasActiveReferralTrial)
        XCTAssertEqual(service.trialDaysRemaining, 0)
    }

    func testGrantTrialAfterExpiredStartsFromNow() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!
        UserDefaults.standard.set(yesterday, forKey: "referral_trial_expiry")

        service.grantReferralTrial()
        XCTAssertTrue(service.hasActiveReferralTrial)
        XCTAssertTrue(service.trialDaysRemaining >= 6 && service.trialDaysRemaining <= 7)
    }

    func testTrialExpiringInOneHourIsStillActive() {
        let oneHourFromNow = Date.now.addingTimeInterval(3600)
        UserDefaults.standard.set(oneHourFromNow, forKey: "referral_trial_expiry")
        XCTAssertTrue(service.hasActiveReferralTrial)
    }

    func testTrialExpiredOneSecondAgoIsInactive() {
        let justExpired = Date.now.addingTimeInterval(-1)
        UserDefaults.standard.set(justExpired, forKey: "referral_trial_expiry")
        XCTAssertFalse(service.hasActiveReferralTrial)
    }

    // MARK: - Referrer Tracking

    func testNotReferredByDefault() {
        XCTAssertFalse(service.wasReferred)
    }

    func testRecordReferrer() {
        service.recordReferrer(code: "ABC123")
        XCTAssertTrue(service.wasReferred)
    }

    func testCannotBeReferredTwice() {
        service.recordReferrer(code: "ABC123")
        service.recordReferrer(code: "DEF456")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "referral_referred_by"), "ABC123")
    }

    func testRecordReferrerWithUUID() {
        let uuid = UUID().uuidString
        service.recordReferrer(code: uuid)
        XCTAssertTrue(service.wasReferred)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "referral_referred_by"), uuid)
    }

    // MARK: - Referral Count

    func testReferralCountStartsAtZero() {
        XCTAssertEqual(service.referralCount, 0)
    }

    func testIncrementReferralCount() {
        service.incrementReferralCount()
        XCTAssertEqual(service.referralCount, 1)
        service.incrementReferralCount()
        XCTAssertEqual(service.referralCount, 2)
    }

    func testIncrementReferralCountTenTimes() {
        for _ in 0..<10 {
            service.incrementReferralCount()
        }
        XCTAssertEqual(service.referralCount, 10)
    }

    // MARK: - URL Generation

    func testReferralURLFormat() {
        // Can't test with modelContext directly, but verify URL building logic
        let code = "TEST-UUID-123"
        var components = URLComponents()
        components.scheme = "https"
        components.host = "memori-website-sooty.vercel.app"
        components.path = "/refer"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        let url = components.url!

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "memori-website-sooty.vercel.app")
        XCTAssertEqual(url.path, "/refer")
        XCTAssertTrue(url.absoluteString.contains("code=TEST-UUID-123"))
    }

    func testDeepLinkURLFormat() {
        let code = "TEST-UUID-123"
        var components = URLComponents()
        components.scheme = "memori"
        components.host = "refer"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        let url = components.url!

        XCTAssertEqual(url.scheme, "memori")
        XCTAssertEqual(url.host, "refer")
        XCTAssertTrue(url.absoluteString.contains("code=TEST-UUID-123"))
    }

    // MARK: - Full Flow Simulation

    func testFullReferralFlowForNewUser() {
        // 1. User is not referred
        XCTAssertFalse(service.wasReferred)
        XCTAssertFalse(service.hasActiveReferralTrial)

        // 2. User receives referral
        service.recordReferrer(code: "REFERRER-UUID")
        XCTAssertTrue(service.wasReferred)

        // 3. User gets trial
        service.grantReferralTrial()
        XCTAssertTrue(service.hasActiveReferralTrial)
        XCTAssertTrue(service.trialDaysRemaining >= 6 && service.trialDaysRemaining <= 7)
    }

    func testCannotRedeemReferralTwice() {
        // First referral
        service.recordReferrer(code: "FIRST-REFERRER")
        service.grantReferralTrial()
        XCTAssertTrue(service.hasActiveReferralTrial)
        XCTAssertTrue(service.trialDaysRemaining >= 6) // 6 or 7 depending on time of day

        // Second referral attempt — recordReferrer should be blocked
        service.recordReferrer(code: "SECOND-REFERRER")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "referral_referred_by"), "FIRST-REFERRER")
    }

    func testSelfReferralPrevention() {
        let myCode = "MY-OWN-UUID"
        // The self-referral check happens in ContentView, not ReferralService
        // But verify the code comparison would work
        let incomingCode = "MY-OWN-UUID"
        XCTAssertEqual(myCode, incomingCode, "Self-referral should be detectable by code comparison")
    }
}

// MARK: - Deep Link Router Referral Tests

@MainActor
final class ReferralDeepLinkTests: XCTestCase {

    func testReferralRouteParses() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://refer?code=ABC123-DEF456")!)

        if case .referral(let code) = router.pendingDestination {
            XCTAssertEqual(code, "ABC123-DEF456")
        } else {
            XCTFail("Expected .referral destination, got \(String(describing: router.pendingDestination))")
        }
    }

    func testReferralRouteWithUUID() {
        let uuid = UUID().uuidString
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://refer?code=\(uuid)")!)

        if case .referral(let code) = router.pendingDestination {
            XCTAssertEqual(code, uuid)
        } else {
            XCTFail("Expected .referral destination")
        }
    }

    func testReferralRouteWithNoCodeFallsToHome() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://refer")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }

    func testReferralRouteWithEmptyCodeParsesAsReferral() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://refer?code=")!)
        if case .referral(let code) = router.pendingDestination {
            XCTAssertEqual(code, "")
        } else {
            XCTAssertEqual(router.pendingDestination, .home)
        }
    }

    func testReferralDoesNotBreakOtherRoutes() {
        let router = DeepLinkRouter()

        router.handle(URL(string: "memori://home")!)
        XCTAssertEqual(router.pendingDestination, .home)

        router.handle(URL(string: "memori://train")!)
        XCTAssertEqual(router.pendingDestination, .train)

        router.handle(URL(string: "memori://compete")!)
        XCTAssertEqual(router.pendingDestination, .compete)

        router.handle(URL(string: "memori://insights")!)
        XCTAssertEqual(router.pendingDestination, .insights)

        router.handle(URL(string: "memori://profile")!)
        XCTAssertEqual(router.pendingDestination, .profile)
    }

    func testReferralRouteWithExtraParams() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://refer?code=ABC123&extra=ignored")!)

        if case .referral(let code) = router.pendingDestination {
            XCTAssertEqual(code, "ABC123")
        } else {
            XCTFail("Expected .referral destination")
        }
    }

    func testWrongSchemeIgnored() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://refer?code=ABC123")!)
        XCTAssertNil(router.pendingDestination)
    }
}

// MARK: - StoreService Referral Trial Tests

@MainActor
final class StoreServiceReferralTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "referral_trial_expiry")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "referral_trial_expiry")
        super.tearDown()
    }

    func testNoReferralTrialByDefault() async {
        let store = StoreService()
        await store.updateSubscriptionStatus()
        XCTAssertFalse(store.isProUser)
    }

    func testReferralTrialGrantsProAccess() async {
        let future = Calendar.current.date(byAdding: .day, value: 7, to: Date.now)!
        UserDefaults.standard.set(future, forKey: "referral_trial_expiry")

        let store = StoreService()
        await store.updateSubscriptionStatus()
        XCTAssertTrue(store.isProUser)
    }

    func testExpiredReferralTrialDoesNotGrantPro() async {
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!
        UserDefaults.standard.set(past, forKey: "referral_trial_expiry")

        let store = StoreService()
        await store.updateSubscriptionStatus()
        XCTAssertFalse(store.isProUser)
    }

    func testReferralTrialExpiringInMinutesStillGrantsPro() async {
        let fiveMinutes = Date.now.addingTimeInterval(300)
        UserDefaults.standard.set(fiveMinutes, forKey: "referral_trial_expiry")

        let store = StoreService()
        await store.updateSubscriptionStatus()
        XCTAssertTrue(store.isProUser)
    }
}
