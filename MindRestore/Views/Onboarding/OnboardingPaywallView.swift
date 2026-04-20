import SwiftUI
import StoreKit

struct OnboardingPaywallView: View {
    let brainAge: Int?
    let onContinue: () -> Void

    @Environment(StoreService.self) private var storeService
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTier: SubscriptionTier = .ultra
    @State private var selectedPlan: String = StoreService.weeklyUltraProductID
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Headline
                    headlineSection
                        .padding(.top, 32)

                    // MARK: - Tier Selector
                    tierSelector

                    // MARK: - Benefits List
                    benefitsList

                    // MARK: - Price Options
                    priceOptions
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            // MARK: - Bottom Buttons (pinned)
            bottomButtons
        }
        .background(
            ZStack {
                paywallBackground
                tierAtmosphere
            }
            .ignoresSafeArea()
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            Analytics.paywallShown(trigger: "onboarding")
        }
    }

    // MARK: - Headline

    @ViewBuilder
    private var headlineSection: some View {
        VStack(spacing: 8) {
            if let brainAge {
                VStack(spacing: 4) {
                    Text("Your brain age is \(brainAge).")
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text("Let's fix that.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(selectedAccentColor)
                }
            } else {
                Text("Unlock your full potential")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    // MARK: - Tier Selector

    private var tierSelector: some View {
        HStack(spacing: 0) {
            tierSegment(
                title: "Pro",
                badge: nil,
                isSelected: selectedTier == .pro,
                accentGradient: AppColors.accentGradient
            ) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    selectedTier = .pro
                    selectedPlan = StoreService.monthlyProductID
                }
            }

            tierSegment(
                title: "Ultra",
                badge: "Best value",
                isSelected: selectedTier == .ultra,
                accentGradient: LinearGradient(
                    colors: [AppColors.violet, AppColors.indigo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    selectedTier = .ultra
                    selectedPlan = StoreService.weeklyUltraProductID
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppColors.cardElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private func tierSegment(
        title: String,
        badge: String?,
        isSelected: Bool,
        accentGradient: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : .primary)

                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.88) : .secondary)
                        .textCase(.uppercase)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AnyShapeStyle(accentGradient) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Benefits List

    private var benefitsList: some View {
        VStack(spacing: 0) {
            if selectedTier == .pro {
                benefitRow(icon: "infinity", text: "Unlimited brain games")
                benefitRow(icon: "chart.bar.fill", text: "Detailed insights & analytics")
                benefitRow(icon: "brain.head.profile.fill", text: "All 10 exercises")
            } else {
                benefitRow(icon: "infinity", text: "Unlimited brain games")
                benefitRow(icon: "shield.fill", text: "Block unlimited distracting apps")
                benefitRow(icon: "gamecontroller.fill", text: "Play brain games to unlock apps")
                benefitRow(icon: "chart.bar.fill", text: "Detailed insights & analytics")
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: selectedTier)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selectedAccentColor)
                .frame(width: 24, alignment: .center)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Price Options

    private var priceOptions: some View {
        VStack(spacing: 8) {
            if selectedTier == .ultra {
                PlanCard(
                    title: "Weekly",
                    price: storeService.weeklyUltraProduct?.displayPrice ?? "$2.99/wk",
                    detail: "Billed weekly",
                    trialText: trialLabel(for: storeService.weeklyUltraProduct),
                    badge: nil,
                    isSelected: selectedPlan == StoreService.weeklyUltraProductID,
                    accentColor: selectedAccentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlan = StoreService.weeklyUltraProductID
                    }
                }

                PlanCard(
                    title: "Monthly",
                    price: storeService.monthlyUltraProduct?.displayPrice ?? "$6.99/mo",
                    detail: "Billed monthly",
                    trialText: trialLabel(for: storeService.monthlyUltraProduct),
                    badge: nil,
                    isSelected: selectedPlan == StoreService.monthlyUltraProductID,
                    accentColor: selectedAccentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlan = StoreService.monthlyUltraProductID
                    }
                }

                PlanCard(
                    title: "Annual",
                    price: storeService.annualUltraProduct?.displayPrice ?? "$39.99/yr",
                    detail: ultraAnnualPerMonthDetail,
                    trialText: trialLabel(for: storeService.annualUltraProduct),
                    badge: "Save 52%",
                    isSelected: selectedPlan == StoreService.annualUltraProductID,
                    accentColor: selectedAccentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlan = StoreService.annualUltraProductID
                    }
                }
            } else {
                PlanCard(
                    title: "Monthly",
                    price: storeService.monthlyProduct?.displayPrice ?? "$3.99/mo",
                    detail: "Billed monthly",
                    trialText: trialLabel(for: storeService.monthlyProduct),
                    badge: nil,
                    isSelected: selectedPlan == StoreService.monthlyProductID,
                    accentColor: selectedAccentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlan = StoreService.monthlyProductID
                    }
                }

                PlanCard(
                    title: "Annual",
                    price: storeService.annualProduct?.displayPrice ?? "$19.99/yr",
                    detail: proAnnualPerMonthDetail,
                    trialText: trialLabel(for: storeService.annualProduct),
                    badge: "Save 58% · 3-day free trial",
                    isSelected: selectedPlan == StoreService.annualProductID,
                    accentColor: selectedAccentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlan = StoreService.annualProductID
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTier)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if storeService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                                .font(.subheadline.weight(.semibold))
                            Text(ctaButtonLabel)
                                .font(.headline.weight(.bold))
                        }
                    }
                }
                .gradientButton(selectedTier == .ultra ? AppColors.premiumGradient : AppColors.accentGradient)
            }
            .disabled(storeService.isLoading)
            .padding(.horizontal, 20)

            if let error = storeService.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            }

            Button {
                Analytics.paywallDismissed(trigger: "onboarding")
                onContinue()
            } label: {
                Text("Maybe later")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)

            Text("Cancel anytime.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Background

    @ViewBuilder
    private var paywallBackground: some View {
        if colorScheme == .dark {
            ZStack {
                AppColors.pageBgDark
                LinearGradient(
                    colors: [
                        AppColors.indigo.opacity(0.18),
                        AppColors.accent.opacity(0.10),
                        AppColors.pageBgDark,
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            LinearGradient(
                colors: [
                    AppColors.pageBgLight,
                    AppColors.accent.opacity(0.07),
                    AppColors.accent.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var tierAtmosphere: some View {
        if selectedTier == .ultra {
            LinearGradient(
                colors: [
                    AppColors.violet.opacity(0.12),
                    AppColors.indigo.opacity(0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [
                    AppColors.accent.opacity(0.025),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Helpers

    private var selectedAccentColor: Color {
        selectedTier == .ultra ? AppColors.violet : AppColors.accent
    }

    private var proAnnualPerMonthDetail: String {
        if let annualProduct = storeService.annualProduct,
           let monthlyProduct = storeService.monthlyProduct {
            let monthlyFromAnnual = annualProduct.price / 12
            let formatted = monthlyFromAnnual.formatted(.currency(code: annualProduct.priceFormatStyle.currencyCode ?? "USD"))
            let diff = NSDecimalNumber(decimal: monthlyProduct.price - monthlyFromAnnual)
            let total = NSDecimalNumber(decimal: monthlyProduct.price)
            let savings = Int((diff.doubleValue / total.doubleValue * 100).rounded())
            return "Just \(formatted)/month — Save \(savings)%"
        }
        return "Just $1.67/month — Save 58%"
    }

    private var ultraAnnualPerMonthDetail: String {
        if let annualProduct = storeService.annualUltraProduct,
           let monthlyProduct = storeService.monthlyUltraProduct {
            let monthlyFromAnnual = annualProduct.price / 12
            let formatted = monthlyFromAnnual.formatted(.currency(code: annualProduct.priceFormatStyle.currencyCode ?? "USD"))
            let diff = NSDecimalNumber(decimal: monthlyProduct.price - monthlyFromAnnual)
            let total = NSDecimalNumber(decimal: monthlyProduct.price)
            let savings = Int((diff.doubleValue / total.doubleValue * 100).rounded())
            return "Just \(formatted)/month — Save \(savings)%"
        }
        return "Just $3.33/month — Save 52%"
    }

    private func trialLabel(for product: Product?) -> String {
        if let product,
           let sub = product.subscription,
           let intro = sub.introductoryOffer,
           intro.paymentMode == .freeTrial {
            let value = intro.period.value
            let unit: String
            switch intro.period.unit {
            case .day:   unit = value == 1 ? "day" : "days"
            case .week:  unit = value == 1 ? "week" : "weeks"
            case .month: unit = value == 1 ? "month" : "months"
            case .year:  unit = value == 1 ? "year" : "years"
            @unknown default: unit = "days"
            }
            return "\(value)-\(unit) free trial"
        }
        return ""
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case StoreService.annualProductID:       return storeService.annualProduct
        case StoreService.monthlyProductID:      return storeService.monthlyProduct
        case StoreService.weeklyProductID:       return storeService.weeklyProduct
        case StoreService.annualUltraProductID:  return storeService.annualUltraProduct
        case StoreService.monthlyUltraProductID: return storeService.monthlyUltraProduct
        case StoreService.weeklyUltraProductID:  return storeService.weeklyUltraProduct
        default:                                 return storeService.weeklyUltraProduct
        }
    }

    private var ctaButtonLabel: String {
        if let product = selectedProduct,
           let sub = product.subscription,
           let intro = sub.introductoryOffer,
           intro.paymentMode == .freeTrial {
            let value = intro.period.value
            let unit: String
            switch intro.period.unit {
            case .day:   unit = "Day"
            case .week:  unit = "Week"
            case .month: unit = "Month"
            case .year:  unit = "Year"
            @unknown default: unit = "Day"
            }
            return "Start \(value)-\(unit) Free Trial"
        }
        return "Subscribe Now"
    }

    private func purchase() async {
        let productID = selectedPlan
        if let product = storeService.products.first(where: { $0.id == productID }) {
            await storeService.purchase(product)
            if storeService.isProUser || storeService.isUltraUser {
                Analytics.paywallConverted(plan: productID, price: NSDecimalNumber(decimal: product.price).doubleValue)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                SoundService.shared.playComplete()
                onContinue()
            }
        } else {
            await storeService.loadProducts()
            if let product = storeService.products.first(where: { $0.id == productID }) {
                await storeService.purchase(product)
                if storeService.isProUser || storeService.isUltraUser {
                    Analytics.paywallConverted(plan: productID, price: NSDecimalNumber(decimal: product.price).doubleValue)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    SoundService.shared.playComplete()
                    onContinue()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Onboarding Paywall — Brain Age") {
    OnboardingPaywallView(brainAge: 42) { }
        .environment(StoreService())
}

#Preview("Onboarding Paywall — No Brain Age") {
    OnboardingPaywallView(brainAge: nil) { }
        .environment(StoreService())
}
