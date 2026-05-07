import SwiftUI
import StoreKit

// MARK: - Paywall plans

private enum PaywallPlan: String, CaseIterable {
    case annual, weekly

    var hasTrial: Bool { self == .annual }

    var productID: String {
        switch self {
        case .annual: return StoreService.annualUltraProductID
        case .weekly: return StoreService.weeklyUltraProductID
        }
    }
}

// MARK: - Design tokens

private enum PW {
    static let bg = AppColors.pageBgDark
    static let accent = AppColors.accent
    static let amber = AppColors.amber
    static let mint = AppColors.mint
    static let fg = Color.white
    static let fg2 = Color.white.opacity(0.86)
    static let fgMuted = Color.white.opacity(0.62)
    static let fg3 = Color.white.opacity(0.38)
    static let fg4 = Color.white.opacity(0.22)
    static let hairline = Color.white.opacity(0.06)
    static let closeFill = AppColors.pageBgDark.opacity(0.72)
}

// MARK: - PaywallView

struct PaywallView: View {
    var isHighIntent: Bool = false
    var currentStreak: Int = 0
    var todayScoreGain: Int = 0
    var isPersonalBest: Bool = false
    var gamesPlayedToday: Int = 0
    var triggerSource: String = "unknown"
    var dailyScreenTimeHours: Double = 4.72 // fallback ~4h 43m

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var storeService

    @State private var selectedPlan: PaywallPlan = .annual
    @State private var showExitOffer = false
    @State private var hasSeenExitOffer = false
    @AppStorage("exitOfferShownCount") private var exitOfferShownCount: Int = 0
    private let maxExitOffers = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                PW.bg.ignoresSafeArea()
                atmosphere
                content(
                    safeTop: proxy.safeAreaInsets.top,
                    safeBottom: proxy.safeAreaInsets.bottom,
                    height: proxy.size.height
                )
                closeButton(safeTop: proxy.safeAreaInsets.top, width: proxy.size.width)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showExitOffer) {
            ExitOfferSheet {
                showExitOffer = false
                Task { await purchaseExitOffer() }
            } onDismiss: {
                showExitOffer = false
                Analytics.paywallDismissed(trigger: "exitOffer")
                dismiss()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(PW.bg)
        }
        .onAppear { Analytics.paywallShown(trigger: triggerSource) }
    }

    // MARK: - Atmosphere

    private var atmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PW.accent.opacity(0.11),
                    PW.bg.opacity(0.0),
                    PW.bg.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            Ellipse()
                .fill(PW.accent.opacity(0.14))
                .frame(width: 390, height: 260)
                .blur(radius: 62)
                .offset(y: -105)

            Ellipse()
                .stroke(PW.accent.opacity(0.08), lineWidth: 1)
                .frame(width: 540, height: 360)
                .blur(radius: 1)
                .offset(y: -76)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Content

    private func content(safeTop: CGFloat, safeBottom: CGFloat, height: CGFloat) -> some View {
        let compact = height < 720

        return VStack(spacing: 0) {
            Color.clear.frame(height: max(0, safeTop - (compact ? 22 : 28)))

            paywallHero(compact: compact)
                .padding(.bottom, compact ? 14 : 18)

            headline
                .padding(.bottom, 6)

            trialTerms
                .padding(.bottom, compact ? 16 : 20)

            planToggle
                .frame(maxWidth: 268)
                .padding(.bottom, compact ? 22 : 28)

            trialTimeline(compact: compact)

            Spacer(minLength: compact ? 12 : 18)

            Button {
                Task { await storeService.restorePurchases() }
            } label: {
                Text("Restore purchases")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(PW.accent)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)

            footer
                .padding(.bottom, 14)

            ctaButton
                .frame(maxWidth: 340)

            Color.clear.frame(height: max(8, safeBottom - 14))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Hero

    private func paywallHero(compact: Bool) -> some View {
        ZStack {
            heroLightField(compact: compact)

            Image("mascot-unlocked")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 158 : 184, height: compact ? 158 : 184)
                .shadow(color: PW.accent.opacity(0.30), radius: 24, y: 12)
                .shadow(color: Color.black.opacity(0.34), radius: 18, y: 10)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 164 : 188)
        .accessibilityHidden(true)
    }

    private func heroLightField(compact: Bool) -> some View {
        ZStack {
            Circle()
                .fill(AppColors.indigo.opacity(0.15))
                .frame(width: compact ? 210 : 242, height: compact ? 210 : 242)
                .blur(radius: 26)

            Ellipse()
                .fill(PW.accent.opacity(0.22))
                .frame(width: compact ? 230 : 272, height: compact ? 120 : 142)
                .blur(radius: 34)
                .offset(y: compact ? 8 : 10)

            Ellipse()
                .fill(AppColors.periwinkle.opacity(0.12))
                .frame(width: compact ? 170 : 202, height: compact ? 84 : 98)
                .blur(radius: 26)
                .offset(y: compact ? -18 : -22)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColors.periwinkle.opacity(0.16),
                            PW.accent.opacity(0.08),
                            PW.bg.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: compact ? 92 : 108
                    )
                )
                .frame(width: compact ? 168 : 196, height: compact ? 168 : 196)

            Ellipse()
                .fill(PW.accent.opacity(0.16))
                .frame(width: compact ? 142 : 168, height: compact ? 22 : 26)
                .blur(radius: 14)
                .offset(y: compact ? 66 : 78)
        }
    }

    private var headline: some View {
        Text(selectedPlan.hasTrial ? "How your trial works" : "How your plan works")
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(PW.fg)
            .multilineTextAlignment(.center)
            .kerning(-0.4)
            .minimumScaleFactor(0.88)
            .lineLimit(1)
    }

    private var trialTerms: some View {
        Text(selectedPlan.hasTrial ? "First 7 days free, then $39.99/year" : "$3.99/week. Cancel anytime.")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(PW.fgMuted)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
    }

    // MARK: - Plan Toggle

    private var planToggle: some View {
        HStack(spacing: 0) {
            planSegment(.annual, label: "Annual")
            planSegment(.weekly, label: "Weekly")
        }
        .padding(3)
        .background(Color.white.opacity(0.035), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func planSegment(_ plan: PaywallPlan, label: String) -> some View {
        let selected = selectedPlan == plan
        return Button {
            selectedPlan = plan
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(selected ? PW.fg : PW.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selected ? PW.accent : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Trial Timeline

    private func trialTimeline(compact: Bool) -> some View {
        VStack(spacing: compact ? 20 : 25) {
            trialStep(
                icon: "lock.open.fill",
                title: "Today",
                body: "Unlock every game and guard every target.",
                compact: compact
            )
            trialStep(
                icon: selectedPlan.hasTrial ? "bell.fill" : "xmark.circle.fill",
                title: selectedPlan.hasTrial ? "In 5 days" : "Anytime",
                body: selectedPlan.hasTrial
                    ? "Memo reminds you before billing starts."
                    : "Cancel in the App Store whenever you want.",
                compact: compact
            )
            trialStep(
                icon: "creditcard.fill",
                title: selectedPlan.hasTrial ? "In 7 days" : "Every 7 days",
                body: selectedPlan == .annual
                    ? "Your annual plan starts unless canceled."
                    : "Your weekly plan starts unless canceled.",
                compact: compact
            )
        }
        .background(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 2)
                .padding(.leading, compact ? 21 : 22)
                .padding(.vertical, compact ? 25 : 27)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: 340)
    }

    private func trialStep(icon: String, title: String, body: String, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 16 : 18) {
            ZStack {
                Circle()
                    .fill(PW.accent)
                    .frame(width: compact ? 44 : 46, height: compact ? 44 : 46)

                Image(systemName: icon)
                    .font(.system(size: compact ? 16 : 17, weight: .bold))
                    .foregroundStyle(PW.fg)
            }
            .zIndex(1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(PW.fg)

                Text(body)
                    .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(PW.fgMuted)
                    .lineSpacing(1)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, compact ? 4 : 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            Task { await purchaseSelectedPlan() }
        } label: {
            Text(selectedPlan.hasTrial ? "Start Free Trial" : "Start Weekly Access")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(PW.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: PW.accent.opacity(0.30), radius: 28, y: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        Text(selectedPlan.hasTrial
             ? "7 days free, then $39.99/year. Cancel anytime."
             : "$3.99/week. Cancel anytime in the App Store")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(PW.fg3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Close Button

    private func closeButton(safeTop: CGFloat, width: CGFloat) -> some View {
        Button {
            if hasSeenExitOffer || !isHighIntent || exitOfferShownCount >= maxExitOffers {
                Analytics.paywallDismissed(trigger: isHighIntent ? "highIntent" : "browse")
                dismiss()
            } else {
                showExitOffer = true
                hasSeenExitOffer = true
                exitOfferShownCount += 1
            }
        } label: {
            ZStack {
                Circle()
                    .fill(PW.closeFill)
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    .frame(width: 34, height: 34)

                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PW.fg)
            }
            .frame(width: 50, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .padding(.top, max(8, safeTop - 18))
        .padding(.trailing, 12)
        .frame(width: width, height: max(68, safeTop + 44), alignment: .topTrailing)
        .offset(y: -38)
    }

    // MARK: - Purchase

    private func purchaseSelectedPlan() async {
        await purchase(productID: selectedPlan.productID)
    }

    private func purchaseExitOffer() async {
        await purchase(productID: StoreService.annualUltraExitOfferProductID)
    }

    private func purchase(productID: String) async {
        if let product = storeService.products.first(where: { $0.id == productID }) {
            await completePurchase(product, productID: productID)
        } else {
            await storeService.loadProducts()
            if let product = storeService.products.first(where: { $0.id == productID }) {
                await completePurchase(product, productID: productID)
            } else {
                storeService.purchaseError = "This offer is not ready yet."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func completePurchase(_ product: Product, productID: String) async {
        await storeService.purchase(product)
        if storeService.isProUser {
            Analytics.paywallConverted(plan: productID, price: NSDecimalNumber(decimal: product.price).doubleValue)
            if productID == StoreService.annualUltraProductID || productID == StoreService.annualUltraExitOfferProductID {
                NotificationService.shared.recordTrialStarted(days: 7)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            SoundService.shared.playComplete()
            dismiss()
        }
    }
}

// MARK: - Exit Offer Sheet

struct ExitOfferSheet: View {
    let onSubscribe: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PW.amber.opacity(0.14), PW.bg.opacity(0.0)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 20)

                // Eyebrow
                Text("FOUNDER PRICE")
                    .font(.system(size: 10, weight: .black))
                    .tracking(2)
                    .foregroundStyle(PW.amber)
                    .padding(.bottom, 14)

                // Headline
                Text("Founder price\nunlocked.")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(PW.fg)
                    .lineSpacing(-2)
                    .padding(.bottom, 14)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                // Body
                Text("Memo is still early. Lock in the founder price and help build the anti-doomscroll app Big Tech doesn't want people using.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)

                // Price
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("$39.99")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .strikethrough(true, color: PW.fg3)
                        .foregroundStyle(Color.white.opacity(0.30))

                    Text("$29.99")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(PW.amber)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    Text("/year")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.30))
                }
                .opacity(appeared ? 1 : 0)

                // Value line
                Text("$0.58/week · 7 days free")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(PW.mint)
                    .padding(.top, 6)

                // Qualifier
                Text("Same Pro. Same mission. Lower barrier.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .padding(.top, 6)

                Spacer(minLength: 16)

                // CTA
                Button(action: onSubscribe) {
                    Text("Lock in founder price")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(AppColors.premiumGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: PW.accent.opacity(0.28), radius: 18, y: 12)
                }
                .buttonStyle(.plain)

                // Dismiss
                Button(action: onDismiss) {
                    Text("Not today")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                appeared = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView(isHighIntent: true, triggerSource: "preview")
        .environment(StoreService())
}
