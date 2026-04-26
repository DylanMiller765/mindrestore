import SwiftUI
import SwiftData

struct ReferralInlineRow: View {
    @Environment(ReferralService.self) private var referralService
    @Environment(StoreService.self) private var storeService
    @Environment(\.modelContext) private var modelContext

    private var shareURL: URL {
        referralService.getReferralURL(modelContext: modelContext)
            ?? URL(string: "https://apps.apple.com/app/id6760178716")!
    }

    var body: some View {
        ShareLink(
            item: shareURL,
            subject: Text("Try Memo"),
            message: Text("Try Memo and test your brain age! Use my link to get 1 week of Pro free")
        ) {
            HStack(spacing: 8) {
                Text("🎁")
                    .font(.system(size: 16))

                Text(storeService.isProUser ? "Give a friend 1 week Pro free" : "Invite a friend, get Pro free")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.violet)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(AppColors.violet.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.violet.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
