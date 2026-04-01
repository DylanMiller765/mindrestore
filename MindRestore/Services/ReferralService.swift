import SwiftUI
import SwiftData
import CloudKit

@MainActor
@Observable
final class ReferralService {
    // UserDefaults keys
    private let trialExpiryKey = "referral_trial_expiry"
    private let referredByKey = "referral_referred_by"
    private let referralCountKey = "referral_count"
    private let defaults = UserDefaults.standard

    // CloudKit
    private let container = CKContainer.default()

    // MARK: - Referral Code (user's own ID)

    /// Get the current user's referral code (their UUID)
    func getReferralCode(modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<User>()
        guard let user = try? modelContext.fetch(descriptor).first else { return nil }
        return user.id.uuidString
    }

    /// Build the referral URL for sharing
    func getReferralURL(modelContext: ModelContext) -> URL? {
        guard let code = getReferralCode(modelContext: modelContext) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "getmemoriapp.com"
        components.path = "/refer"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url
    }

    /// Build the direct deep link URL
    func getReferralDeepLink(modelContext: ModelContext) -> URL? {
        guard let code = getReferralCode(modelContext: modelContext) else { return nil }
        var components = URLComponents()
        components.scheme = "memori"
        components.host = "refer"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url
    }

    // MARK: - Trial Management

    /// Whether the user currently has an active referral trial
    var hasActiveReferralTrial: Bool {
        guard let expiry = defaults.object(forKey: trialExpiryKey) as? Date else {
            return false
        }
        return expiry > Date.now
    }

    /// Days remaining on referral trial
    var trialDaysRemaining: Int {
        guard let expiry = defaults.object(forKey: trialExpiryKey) as? Date else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date.now, to: expiry).day ?? 0
        return max(0, days)
    }

    /// Grant 7-day Pro trial to the current user
    func grantReferralTrial() {
        let currentExpiry = defaults.object(forKey: trialExpiryKey) as? Date ?? Date.now
        let baseDate = max(currentExpiry, Date.now)
        let newExpiry = Calendar.current.date(byAdding: .day, value: 7, to: baseDate) ?? Date.now
        defaults.set(newExpiry, forKey: trialExpiryKey)
    }

    /// Record who referred this user
    func recordReferrer(code: String) {
        guard defaults.string(forKey: referredByKey) == nil else { return }
        defaults.set(code, forKey: referredByKey)
    }

    /// Whether this user was already referred by someone
    var wasReferred: Bool {
        defaults.string(forKey: referredByKey) != nil
    }

    // MARK: - Referral Count (for referrer rewards)

    /// How many friends this user has successfully referred
    var referralCount: Int {
        defaults.integer(forKey: referralCountKey)
    }

    /// Increment referral count
    func incrementReferralCount() {
        defaults.set(referralCount + 1, forKey: referralCountKey)
    }

    // MARK: - CloudKit Referrer Rewards (Public DB, no sign-in needed)

    /// Write a pending reward for the referrer to CloudKit
    func notifyReferrer(referrerCode: String) {
        let record = CKRecord(recordType: "ReferralReward")
        record["referrerCode"] = referrerCode as CKRecordValue
        record["status"] = "pending" as CKRecordValue
        record["createdAt"] = Date.now as CKRecordValue

        container.publicCloudDatabase.save(record) { _, error in
            if let error {
                print("CloudKit save error: \(error.localizedDescription)")
            }
        }
    }

    /// Check CloudKit for pending referral rewards for this user
    func checkForPendingRewards(myCode: String) {
        let predicate = NSPredicate(format: "referrerCode == %@ AND status == %@", myCode, "pending")
        let query = CKQuery(recordType: "ReferralReward", predicate: predicate)

        container.publicCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
            switch result {
            case .success(let (matchResults, _)):
                var rewardCount = 0
                for (_, recordResult) in matchResults {
                    if case .success(let record) = recordResult {
                        record["status"] = "claimed" as CKRecordValue
                        self.container.publicCloudDatabase.save(record) { _, _ in }
                        rewardCount += 1
                    }
                }
                if rewardCount > 0 {
                    Task { @MainActor in
                        for _ in 0..<rewardCount {
                            self.grantReferralTrial()
                            self.incrementReferralCount()
                        }
                    }
                }
            case .failure(let error):
                print("CloudKit query error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Share

    /// Present share sheet with referral link
    func shareReferralLink(modelContext: ModelContext) {
        guard let url = getReferralURL(modelContext: modelContext) else { return }
        let text = "Try Memori and test your brain age! Use my link to get 1 week of Pro free 🧠"
        let activityVC = UIActivityViewController(
            activityItems: [text, url],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        Analytics.trackReferralShared()
    }
}
