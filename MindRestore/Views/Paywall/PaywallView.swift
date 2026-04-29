import SwiftUI
import StoreKit

// MARK: - Paywall plans

private enum PaywallPlan: String, CaseIterable {
    case annual, monthly, weekly

    var label: String {
        switch self {
        case .annual:  return "Annual"
        case .monthly: return "Monthly"
        case .weekly:  return "Weekly"
        }
    }

    var total: String {
        switch self {
        case .annual:  return "$49.99"
        case .monthly: return "$7.99"
        case .weekly:  return "$3.99"
        }
    }

    var period: String {
        switch self {
        case .annual:  return "/year"
        case .monthly: return "/month"
        case .weekly:  return "/week"
        }
    }

    var perMo: String {
        switch self {
        case .annual:  return "$4.16/mo"
        case .monthly: return "$7.99/mo"
        case .weekly:  return "$3.99/wk"
        }
    }

    var hasTrial: Bool { self == .annual }

    var saveLabel: String? {
        self == .annual ? "BEST VALUE · 48% OFF" : nil
    }

    var productID: String {
        switch self {
        case .annual:  return StoreService.annualUltraProductID
        case .monthly: return StoreService.monthlyUltraProductID
        case .weekly:  return StoreService.weeklyUltraProductID
        }
    }
}

// MARK: - Design tokens (v9-finch spec, dark mode default)

private enum PW {
    static let bg          = Color(red: 0.039, green: 0.039, blue: 0.059)   // #0A0A0F
    static let surface     = Color.white.opacity(0.05)
    static let surface2    = Color.white.opacity(0.08)
    static let line        = Color.white.opacity(0.10)
    static let brand       = Color(red: 0.408, green: 0.565, blue: 0.996)   // #6890FE
    static let brandDeep   = Color(red: 0.290, green: 0.498, blue: 0.898)   // #4A7FE5
    static let brandGlow   = Color(red: 0.408, green: 0.565, blue: 0.996).opacity(0.35)
    static let sky         = Color(red: 0.082, green: 0.047, blue: 0.180)   // #150C2E
    static let fg          = Color.white.opacity(0.94)
    static let fg2         = Color.white.opacity(0.62)
    static let fg3         = Color.white.opacity(0.40)
    static let amber       = Color(red: 1.0,   green: 0.761, blue: 0.278)   // #FFC247
    static let coral       = Color(red: 0.980, green: 0.420, blue: 0.349)   // #FA6B59
    static let mint        = Color(red: 0.0,   green: 0.820, blue: 0.620)   // #00D19E
    static let pink        = Color(red: 0.922, green: 0.302, blue: 0.549)   // #EB4D8C
    static let badgeText   = Color(red: 0.10,  green: 0.10,  blue: 0.10)    // #1A1A1A on amber badge
}

// MARK: - PaywallView

struct PaywallView: View {
    var isHighIntent: Bool = false
    var currentStreak: Int = 0
    var todayScoreGain: Int = 0
    var isPersonalBest: Bool = false
    var gamesPlayedToday: Int = 0
    var triggerSource: String = "unknown"

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var storeService

    @State private var selectedPlan: PaywallPlan = .annual
    @State private var showingPlansSheet = false
    @State private var showExitOffer = false
    @State private var hasSeenExitOffer = false
    @AppStorage("exitOfferShownCount") private var exitOfferShownCount: Int = 0
    private let maxExitOffers = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                PW.bg.ignoresSafeArea()
                brandGlow
                content(width: proxy.size.width)
                closeButton(safeTop: proxy.safeAreaInsets.top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.container, edges: .horizontal)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingPlansSheet) {
            PlansSheet(
                selected: $selectedPlan,
                onSubscribe: { Task { await purchase() } }
            )
            .presentationDetents([.height(440)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color(red: 0.078, green: 0.078, blue: 0.122))
        }
        .sheet(isPresented: $showExitOffer) {
            ExitOfferSheet {
                showExitOffer = false
                Task { await purchase() }
            } onDismiss: {
                showExitOffer = false
                Analytics.paywallDismissed(trigger: "exitOffer")
                dismiss()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear { Analytics.paywallShown(trigger: triggerSource) }
    }

    // MARK: Layout

    private var brandGlow: some View {
        // Tight halo just around the 220pt mascot (mascot center ≈ y=128 from top).
        ZStack {
            Ellipse()
                .fill(PW.sky)
                .frame(width: 180, height: 150)
                .blur(radius: 40)
            Ellipse()
                .fill(PW.brand.opacity(0.30))
                .frame(width: 220, height: 180)
                .blur(radius: 50)
        }
        .offset(y: 38)
        .allowsHitTesting(false)
    }

    private func content(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            heroSection
            bodySection(width: width)
        }
        .frame(width: width, alignment: .top)
    }

    private var heroSection: some View {
        ZStack {
            // Confetti — placed in a 360pt-wide canvas so layout matches the design grid.
            Group {
                confettiDot(x: 56,  y: 30,  color: PW.coral, shape: .circle, size: 8)
                confettiDot(x: 92,  y: 70,  color: PW.amber, shape: .diamond, size: 11, rotate: 20)
                confettiDot(x: 38,  y: 140, color: PW.mint,  shape: .diamond, size: 9,  rotate: -15)
                confettiDot(x: 300, y: 20,  color: PW.amber, shape: .circle, size: 7)
                confettiDot(x: 324, y: 68,  color: PW.mint,  shape: .diamond, size: 10, rotate: 30)
                confettiDot(x: 350, y: 120, color: PW.pink,  shape: .circle, size: 8)
                confettiDot(x: 70,  y: 210, color: PW.amber, shape: .diamond, size: 9,  rotate: -30)
                confettiDot(x: 310, y: 210, color: PW.coral, shape: .diamond, size: 11, rotate: 45)
            }
            .frame(width: 360, height: 220, alignment: .topLeading)

            Image("mascot-unlocked")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
        }
        .frame(height: 220)
        .padding(.top, 18)
    }

    private enum ConfettiShape { case circle, diamond }

    private func confettiDot(x: CGFloat, y: CGFloat, color: Color, shape: ConfettiShape, size: CGFloat, rotate: Double = 0) -> some View {
        Group {
            if shape == .circle {
                Circle().fill(color)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(color)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotate))
        .shadow(color: color.opacity(0.5), radius: 4)
        .position(x: x, y: y)
    }

    private func bodySection(width: CGFloat) -> some View {
        let inner = max(width - 44, 0)  // 22pt horizontal padding each side
        return VStack(spacing: 0) {
            headline
                .frame(width: inner)
                .padding(.bottom, 6)

            subtitle
                .frame(width: inner)
                .padding(.bottom, 22)

            featuresList
                .frame(width: inner)
                .padding(.bottom, 18)

            Spacer(minLength: 8)

            priceLine
                .frame(width: inner)
                .padding(.bottom, 12)

            ctaButton
                .frame(width: inner)
                .padding(.bottom, 10)

            seeOtherPlansLink
                .frame(width: inner)
                .padding(.bottom, 6)

            restoreButton
                .frame(width: inner)
                .padding(.bottom, 4)
        }
        .frame(maxHeight: .infinity)
        .padding(.bottom, 24)
    }

    private var headline: some View {
        HStack(spacing: 10) {
            Text("Subscribe to")
                .font(.system(size: 28, weight: .black))
                .kerning(-0.6)
                .foregroundStyle(PW.fg)

            Text("PRO")
                .font(.system(size: 16, weight: .heavy))
                .kerning(0.96)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [PW.brand, PW.brandDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: PW.brandGlow, radius: 8, y: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var subtitle: some View {
        // JSX has explicit <br/> before "screen time" so the bold fragment wraps to its own line.
        let base = Font.system(size: 14, weight: .medium)
        let strong = Font.system(size: 14, weight: .bold)
        return (
            Text("Pro users train ").font(base).foregroundColor(PW.fg2)
            + Text("2× more").font(strong).foregroundColor(PW.fg)
            + Text(" and ").font(base).foregroundColor(PW.fg2)
            + Text("cut their\nscreen time in half").font(strong).foregroundColor(PW.fg)
            + Text(".").font(base).foregroundColor(PW.fg2)
        )
        .multilineTextAlignment(.center)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private var featuresList: some View {
        VStack(spacing: 16) {
            featureRow(
                icon: "shield.fill",
                title: "Block more than one app",
                body: "Free users can bounce one app. Pro lets Memo block the whole feed."
            )
            featureRow(
                icon: "brain.head.profile",
                title: "Train before you scroll",
                body: "Blocked apps stay locked until you put in a brain-training rep."
            )
            featureRow(
                icon: "timer",
                title: "Earn unlocks",
                body: "Each brain game unlocks 5–60 minutes of screen time. You set the rules."
            )
            featureRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Detailed Brain Score insights",
                body: "See how your memory, speed, attention, and screen-time defense trend."
            )
            featureRow(
                icon: "receipt.fill",
                title: "Paid, not farmed",
                body: "No ads. No data sold. 10% to fight Big Tech."
            )
        }
    }

    private func featureRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PW.brand.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PW.brand.opacity(0.30), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PW.brand)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15.5, weight: .bold))
                    .kerning(-0.15)
                    .foregroundStyle(PW.fg)

                Text(body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PW.fg2)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var priceLine: some View {
        VStack(spacing: 0) {
            Text(selectedPlan.hasTrial ? "7 days free, then" : "Subscribe now for")
                .font(.system(size: 14))
                .foregroundStyle(PW.fg2)

            HStack(spacing: 4) {
                Text("\(selectedPlan.total) \(priceUnit)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(PW.fg)
                if selectedPlan.hasTrial {
                    Text("(\(selectedPlan.perMo))")
                        .font(.system(size: 14))
                        .foregroundStyle(PW.fg2)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var priceUnit: String {
        switch selectedPlan {
        case .annual:  return "per year"
        case .monthly: return "per month"
        case .weekly:  return "per week"
        }
    }

    private var ctaButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            Text(ctaTitle)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [PW.brand, PW.brandDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                        .blendMode(.plusLighter)
                        .mask(
                            VStack(spacing: 0) {
                                Rectangle().frame(height: 1)
                                Spacer()
                            }
                        )
                )
                .shadow(color: PW.brandGlow, radius: 18, y: 14)
        }
        .buttonStyle(.plain)
    }

    private var ctaTitle: String {
        if selectedPlan.hasTrial { return "Start 7-day free trial" }
        return "Subscribe for \(selectedPlan.total)\(selectedPlan.period)"
    }

    private var seeOtherPlansLink: some View {
        Button {
            showingPlansSheet = true
        } label: {
            Text("See other plans")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PW.fg)
                .underline(true, color: PW.fg.opacity(0.7))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var restoreButton: some View {
        Button {
            Task { await storeService.restorePurchases() }
        } label: {
            Text("Restore purchases")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PW.fg3)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func closeButton(safeTop: CGFloat) -> some View {
        HStack {
            Spacer()
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
                        .fill(PW.surface2)
                        .overlay(Circle().stroke(PW.line, lineWidth: 1))
                        .frame(width: 36, height: 36)

                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PW.fg)
                }
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .accessibilityHint(isHighIntent ? "Shows the exit offer or closes the paywall" : "Closes the paywall")
        }
        .padding(.top, max(14, safeTop + 10))
        .padding(.trailing, 12)
    }

    // MARK: Purchase

    private func purchase() async {
        let productID = selectedPlan.productID
        if let product = storeService.products.first(where: { $0.id == productID }) {
            await storeService.purchase(product)
        } else {
            await storeService.loadProducts()
            if let product = storeService.products.first(where: { $0.id == productID }) {
                await storeService.purchase(product)
            }
        }
        if storeService.isProUser {
            if let product = storeService.products.first(where: { $0.id == productID }) {
                Analytics.paywallConverted(plan: productID, price: NSDecimalNumber(decimal: product.price).doubleValue)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            SoundService.shared.playComplete()
            dismiss()
            // Highest-commitment positive interaction we'll ever get — they paid.
            // Delay long enough that the paywall sheet finishes dismissing and
            // the host view's success state has rendered before iOS overlays
            // its native review alert.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                ReviewPromptService.requestForNewSubscriber()
            }
        }
    }
}

// MARK: - Plans Sheet (See other plans)

private struct PlansSheet: View {
    @Binding var selected: PaywallPlan
    var onSubscribe: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose your plan")
                    .font(.system(size: 22, weight: .black))
                    .kerning(-0.4)
                    .foregroundStyle(PW.fg)

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PW.fg)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(PW.surface2))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 18)

            VStack(spacing: 14) {
                ForEach(PaywallPlan.allCases, id: \.self) { plan in
                    planRow(plan)
                }
            }
            .padding(.bottom, 18)

            Button {
                dismiss()
                onSubscribe()
            } label: {
                Text(sheetCtaTitle)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [PW.brand, PW.brandDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: PW.brandGlow, radius: 14, y: 10)
            }
            .buttonStyle(.plain)

            Text(sheetDisclaimer)
                .font(.system(size: 11.5))
                .foregroundStyle(PW.fg3)
                .padding(.top, 12)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 32)
    }

    private var sheetCtaTitle: String {
        if selected.hasTrial { return "Start 7-day free trial" }
        return "Subscribe for \(selected.total)\(selected.period)"
    }

    private var sheetDisclaimer: String {
        if selected.hasTrial {
            return "Then \(selected.total)/year · Cancel anytime"
        }
        return "Renews automatically · Cancel anytime"
    }

    private func planRow(_ plan: PaywallPlan) -> some View {
        let active = plan == selected
        return Button {
            selected = plan
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.label + (plan.hasTrial ? " · 7-day free trial" : ""))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(PW.fg)

                    Text(plan.perMo + (plan == .annual ? " · billed yearly" : ""))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(active ? PW.brand : PW.fg2)
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(plan.total)
                        .font(.system(size: 17, weight: .heavy))
                        .kerning(-0.15)
                        .foregroundStyle(active ? PW.brand : PW.fg)
                    Text(plan.period)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(active ? PW.brand.opacity(0.7) : PW.fg2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(active ? PW.brand.opacity(0.18) : PW.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(active ? PW.brand : PW.line, lineWidth: 2)
            )
            .overlay(alignment: .topLeading) {
                if let badge = plan.saveLabel {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .heavy))
                        .kerning(0.76)
                        .foregroundStyle(PW.badgeText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(PW.amber))
                        .offset(x: 14, y: -9)
                }
            }
            .shadow(color: active ? PW.brandGlow : .clear, radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exit Offer Sheet

struct ExitOfferSheet: View {
    let onSubscribe: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("mascot-locked-sad")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 140)
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("Don't lose your\nmomentum!")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Pro keeps Memo on patrol — more apps\nblocked, more unlocks earned.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            VStack(spacing: 12) {
                Button(action: onSubscribe) {
                    Text("Unlock Pro")
                        .gradientButton()
                }

                Button(action: onDismiss) {
                    Text("No thanks")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
        .environment(StoreService())
}
