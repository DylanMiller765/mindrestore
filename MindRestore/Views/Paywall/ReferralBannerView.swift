import SwiftUI
import SwiftData

struct ReferralBannerView: View {
    @Environment(ReferralService.self) private var referralService
    @Environment(StoreService.self) private var storeService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var glow = false

    private var isProUser: Bool { storeService.isProUser }

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
            HStack(spacing: 0) {
                Image("mascot-wave")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isProUser ? "Give a week of Pro" : "Get Pro for free")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)

                    Text(isProUser ? "Friend gets 1 week free, you earn another" : "Invite 1 friend → 1 week Pro each")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.75) : .secondary)
                }

                Spacer()

                Text("Share")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppColors.accent))
                    .padding(.trailing, 14)
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(colorScheme == .dark
                        ? LinearGradient(
                            colors: [Color(red: 0.2, green: 0.2, blue: 0.35), Color(red: 0.15, green: 0.12, blue: 0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(
                            colors: [Color(.systemBackground), Color(.systemBackground)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: colorScheme == .dark
                        ? AppColors.violet.opacity(glow ? 0.5 : 0.2)
                        : AppColors.accent.opacity(glow ? 0.2 : 0.1),
                        radius: glow ? 16 : 8, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(colorScheme == .dark ? .clear : AppColors.accent.opacity(0.3), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
