import SwiftUI
import SwiftData
import Charts
import DeviceActivity
import FamilyControls

// MARK: - Time Range

private enum TimeRange: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"

    var days: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        }
    }

    var iconName: String {
        switch self {
        case .today: return "sun.max.fill"
        case .week: return "calendar"
        case .month: return "chart.bar.xaxis"
        }
    }

    var sortIndex: Int {
        switch self {
        case .today: return 0
        case .week: return 1
        case .month: return 2
        }
    }
}

private enum InsightsMode: String, CaseIterable {
    case brain = "Brain"
    case focus = "Focus"

    var iconName: String {
        switch self {
        case .brain: return "brain.head.profile"
        case .focus: return "shield.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .brain: return AppColors.accent
        case .focus: return AppColors.mint
        }
    }

    var sortIndex: Int {
        switch self {
        case .brain: return 0
        case .focus: return 1
        }
    }
}

private struct FocusInsightOffender: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let durationSeconds: TimeInterval
    let opens: Int
    let iconAssetName: String?
}

private struct FocusInsightSnapshot {
    let screenTimeSeconds: TimeInterval
    let pickups: Int
    let weeklyScreenTimeHours: [Double]
    let baselineDailyAverageSeconds: TimeInterval?
    let protectedMinutes: Int
    let unlockReps: Int
    let blockedAttempts: Int
    let targetCount: Int
    let passMinutes: Int
    let offenders: [FocusInsightOffender]
    let isDemoData: Bool

    static let empty = FocusInsightSnapshot(
        screenTimeSeconds: 0,
        pickups: 0,
        weeklyScreenTimeHours: [],
        baselineDailyAverageSeconds: nil,
        protectedMinutes: 0,
        unlockReps: 0,
        blockedAttempts: 0,
        targetCount: 0,
        passMinutes: 0,
        offenders: [],
        isDemoData: false
    )
}

private struct FocusReceiptHeroData {
    let topAppName: String
    let topAppSeconds: TimeInterval
    let totalPullSeconds: TimeInterval
    let latestPullSeconds: TimeInterval
    let averagePullSeconds: TimeInterval
    let pickups: Int
}

private struct FocusHistoryItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let hours: Double
}

// MARK: - Insights Dashboard

struct ProgressDashboardView: View {
    @Environment(StoreService.self) private var storeService
    @Environment(FocusModeService.self) private var focusModeService
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @Query private var achievements: [Achievement]
    @Query(sort: \Exercise.completedAt, order: .reverse) private var exercises: [Exercise]

    @State private var selectedRange: TimeRange = .week
    @State private var selectedMode: InsightsMode = .focus
    @State private var selectedFocusHistoryIndex = 6
    @State private var hasSetInitialMode = false
    @State private var showingPaywall = false
    @State private var focusReceiptRefreshToken = Date()
    @State private var focusSnapshot = FocusInsightSnapshot.empty
    @State private var modeTransitionDirection = 1
    @State private var rangeTransitionDirection = 1

    private let forceDemoFocusReport: Bool
    private let previewFocusSnapshot: FocusInsightSnapshot?

    init() {
        self.forceDemoFocusReport = false
        self.previewFocusSnapshot = nil
    }

    #if DEBUG
    fileprivate init(forceDemoFocusReport: Bool, previewFocusSnapshot: FocusInsightSnapshot?) {
        self.forceDemoFocusReport = forceDemoFocusReport
        self.previewFocusSnapshot = previewFocusSnapshot
    }
    #endif

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }
    private var focusSnapshotHasPushback: Bool {
        focusSnapshot.protectedMinutes > 0 || focusSnapshot.unlockReps > 0 || focusSnapshot.blockedAttempts > 0
    }
    private var hasAnyInsightData: Bool {
        !sessions.isEmpty
            || !brainScores.isEmpty
            || focusModeService.isEnabled
            || focusModeService.blockedAppCount > 0
            || focusModeService.dailyAttemptCount > 0
            || focusSnapshot.screenTimeSeconds > 0
            || focusSnapshot.protectedMinutes > 0
    }

    private var effectiveFocusRange: TimeRange {
        return selectedRange
    }

    private var focusInsightsFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let end = Date()
        let todayStart = calendar.startOfDay(for: end)
        let start: Date

        switch selectedRange {
        case .today:
            start = todayStart
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        case .month:
            start = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        }

        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    // MARK: - Filtered Data

    private var cutoffDate: Date {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        if selectedRange == .today {
            return todayStart
        }
        return calendar.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
    }

    private var filteredScores: [BrainScoreResult] {
        brainScores.filter { $0.date >= cutoffDate }
    }

    private var filteredExercises: [Exercise] {
        exercises.filter { $0.completedAt >= cutoffDate }
    }

    /// Current (latest) brain score
    private var currentScore: BrainScoreResult? {
        brainScores.first
    }

    /// Brain score at the start of the selected period (or earliest in range)
    private var periodStartScore: BrainScoreResult? {
        filteredScores.last
    }

    /// Delta: current brain score minus score at start of period
    private var scoreDelta: Int {
        guard let current = currentScore, let start = periodStartScore,
              current.id != start.id else { return 0 }
        return current.brainScore - start.brainScore
    }

    /// Delta for brain age (lower is better)
    private var brainAgeDelta: Int {
        guard let current = currentScore, let start = periodStartScore,
              current.id != start.id else { return 0 }
        return current.brainAge - start.brainAge
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                if !hasAnyInsightData {
                    emptyState
                } else {
                    VStack(spacing: 22) {
                        insightsModePicker

                        Group {
                            switch selectedMode {
                            case .brain:
                                brainInsightsTab
                            case .focus:
                                focusInsightsTab
                            }
                        }
                        .id(selectedMode)
                        .transition(modePageTransition)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 220)
                    .responsiveContent()
                    .frame(maxWidth: .infinity)
                    .animation(.smooth(duration: 0.52), value: selectedMode)
                }
            }
            .pageBackground()
            .navigationTitle("Insights")
            .toolbar(.automatic, for: .navigationBar)
            .onAppear {
                persistFocusReceiptPushbackDefaults()
                refreshFocusSnapshot()
                guard !hasSetInitialMode else { return }
                selectedMode = .focus
                hasSetInitialMode = true
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .onReceive(Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()) { date in
                guard selectedMode == .focus else { return }
                persistFocusReceiptPushbackDefaults()
                refreshFocusSnapshot()
                focusReceiptRefreshToken = date
            }
            .onChange(of: selectedMode) { _, newMode in
                guard newMode == .focus else { return }
                persistFocusReceiptPushbackDefaults()
                refreshFocusSnapshot()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
                .frame(height: 28)

            Image("mascot-bored")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 128)

            VStack(spacing: 8) {
                Text("No signal yet.")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Play one brain game so Memo can start tracking your brain.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Start first rep")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 28)

            Spacer()
                .frame(height: 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Mode Picker

    private var insightsModePicker: some View {
        HStack(spacing: 24) {
            ForEach(InsightsMode.allCases, id: \.self) { mode in
                Button {
                    guard selectedMode != mode else { return }
                    modeTransitionDirection = mode.sortIndex > selectedMode.sortIndex ? 1 : -1
                    if mode == .focus {
                        persistFocusReceiptPushbackDefaults()
                    }
                    withAnimation(.smooth(duration: 0.52)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text(mode.rawValue)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(selectedMode == mode ? .primary : AppColors.textSecondary)
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(mode.accentColor)
                            .frame(width: selectedMode == mode ? 18 : 0, height: 2)
                            .opacity(selectedMode == mode ? 1 : 0)
                    }
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.rawValue) insights")
                .accessibilityAddTraits(selectedMode == mode ? [.isSelected] : [])
            }

            Spacer(minLength: 0)
        }
    }

    private var modePageTransition: AnyTransition {
        let insertionEdge: Edge = modeTransitionDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = modeTransitionDirection > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    // MARK: - Brain Tab

    private var brainInsightsTab: some View {
        VStack(spacing: 24) {
            trainingSignalSection
            sectionDivider
            brainCompactStatsSection
            sectionDivider
            cognitiveDomainsSection

            if isProUser {
                sectionDivider
                personalBestsSection
                sectionDivider
                trainingHeatmapSection
            } else {
                sectionDivider
                proSectionsTeaser
            }
        }
    }

    private var trainingSignalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let score = currentScore {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Brain Score")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(score.brainScore)")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()

                        if isProUser, scoreDelta != 0 {
                            deltaLabel(value: scoreDelta, inverted: false)
                        }
                    }
                }
            }

            localRangeChips(accent: AppColors.accent)
                .padding(.top, 6)

            if isProUser {
                if selectedRange == .today {
                    todayBrainReceipt
                } else if filteredScores.count >= 2 {
                    trendlineChart
                        .frame(height: 160)
                } else {
                    quietEmptyText("Play again to build a trendline.")
                        .frame(maxWidth: .infinity, minHeight: 84)
                }
            } else {
                chartProTeaser
            }
        }
    }

    private var todayBrainReceipt: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 30, height: 30)
                .background(AppColors.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Today is your latest checkpoint.")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Play one rep to move the line again.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
    }

    private var brainCompactStatsSection: some View {
        HStack(spacing: 0) {
            insightStatColumn(
                title: "Brain Age",
                value: currentScore.map { "\($0.brainAge)y" } ?? "--",
                color: .primary
            )

            verticalDivider

            insightStatColumn(
                title: "Streak",
                value: "\(user?.currentStreak ?? 0)d",
                color: .primary
            )

            verticalDivider

            insightStatColumn(
                title: "Games",
                value: "\(filteredExercises.count)",
                color: .primary
            )
        }
    }

    // MARK: - Focus Tab

    private var focusInsightsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            focusReportHero
            focusRangeTextTabs
            focusLiveReport
        }
    }

    private var focusReportHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(focusSnapshotHasPushback ? "They pulled.\nMemo pushed." : "They pulled.\nMemo is learning.")
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Screen Time stays on your phone.")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, 2)
    }

    private var focusRangeTextTabs: some View {
        HStack(spacing: 26) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    guard selectedRange != range else { return }
                    rangeTransitionDirection = range.sortIndex > selectedRange.sortIndex ? 1 : -1
                    persistFocusReceiptPushbackDefaults()
                    withAnimation(.smooth(duration: 0.50)) {
                        selectedRange = range
                        selectedFocusHistoryIndex = defaultFocusHistoryIndex(for: range)
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(selectedRange == range ? .primary : AppColors.textSecondary)
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) {
                            Capsule()
                                .fill(AppColors.mint)
                                .frame(width: selectedRange == range ? 22 : 0, height: 2)
                                .opacity(selectedRange == range ? 1 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(range.rawValue) Focus receipt")
                .accessibilityAddTraits(selectedRange == range ? [.isSelected] : [])
            }

            Spacer(minLength: 0)
        }
    }

    private func focusOpenReceiptBand(hero: FocusReceiptHeroData, protectedSeconds: TimeInterval) -> some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.coral.opacity(0.42),
                            AppColors.cardBorder.opacity(0.34),
                            AppColors.mint.opacity(0.42)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            HStack(alignment: .center, spacing: 12) {
                focusReceiptProofSide(
                    eyebrow: "PULLED",
                    title: hero.topAppName,
                    value: hero.topAppSeconds > 0 ? formatReceiptDuration(hero.topAppSeconds) : "--",
                    color: AppColors.coral,
                    assetName: socialLogoAsset(for: hero.topAppName),
                    fallbackSystemName: "app.fill"
                )

                VStack(spacing: 7) {
                    Rectangle()
                        .fill(AppColors.cardBorder.opacity(0.62))
                        .frame(width: 1, height: 32)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(AppColors.textSecondary)

                    Rectangle()
                        .fill(AppColors.cardBorder.opacity(0.62))
                        .frame(width: 1, height: 32)
                }
                .frame(width: 22)

                focusReceiptProofSide(
                    eyebrow: "PUSHED BACK",
                    title: "Memo",
                    value: protectedSeconds > 0 ? formatProtectedMinutes(focusSnapshot.protectedMinutes) : "--",
                    color: AppColors.mint,
                    assetName: focusHeroMascotAsset(for: hero),
                    fallbackSystemName: "brain.head.profile"
                )
            }
            .padding(.vertical, 2)

            HStack(spacing: 0) {
                focusReceiptMetaItem(systemName: "shield.checkered", text: focusSnapshot.blockedAttempts == 1 ? "1 block" : "\(focusSnapshot.blockedAttempts) blocks")

                Rectangle()
                    .fill(AppColors.cardBorder.opacity(0.54))
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 14)

                focusReceiptMetaItem(systemName: "lock.open", text: focusSnapshot.unlockReps == 1 ? "1 rep" : "\(focusSnapshot.unlockReps) reps")
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppColors.cardBorder.opacity(0.34))
                    .frame(height: 1)
            }

            focusHeroProofLine(hero: hero)
                .padding(.top, 1)
        }
        .padding(.vertical, 2)
        .background(alignment: .leading) {
            Circle()
                .fill(AppColors.coral.opacity(0.10))
                .blur(radius: 26)
                .frame(width: 120, height: 120)
                .offset(x: -46)
        }
        .background(alignment: .trailing) {
            Circle()
                .fill(AppColors.mint.opacity(0.10))
                .blur(radius: 28)
                .frame(width: 136, height: 136)
                .offset(x: 44)
        }
    }

    private func focusReceiptProofSide(eyebrow: String, title: String, value: String, color: Color, assetName: String?, fallbackSystemName: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 58, height: 58)

                if let assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: title == "Memo" ? 58 : 44, height: title == "Memo" ? 58 : 44)
                        .clipShape(RoundedRectangle(cornerRadius: title == "Memo" ? 0 : 11, style: .continuous))
                } else {
                    Image(systemName: fallbackSystemName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(color)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func focusReceiptMetaItem(systemName: String, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.textSecondary)

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func focusHeroProofLine(hero: FocusReceiptHeroData) -> some View {
        let total = hero.totalPullSeconds > 0 ? formatReceiptDuration(hero.totalPullSeconds) : "--"
        let blocks = focusSnapshot.blockedAttempts == 1 ? "1 block" : "\(focusSnapshot.blockedAttempts) blocks"
        let reps = focusSnapshot.unlockReps == 1 ? "1 unlock rep" : "\(focusSnapshot.unlockReps) unlock reps"
        let line = Text(total)
            .foregroundStyle(AppColors.coral)
            + Text(" total pull · ")
            .foregroundStyle(AppColors.textSecondary)
            + Text(blocks)
            .foregroundStyle(AppColors.textSecondary)
            + Text(" · ")
            .foregroundStyle(AppColors.textSecondary)
            + Text(reps)
            .foregroundStyle(AppColors.textSecondary)

        return line
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(2)
            .minimumScaleFactor(0.78)
    }

    private func focusWeekNavButton(systemName: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(AppColors.cardBorder.opacity(0.46), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var focusLiveReport: some View {
        if forceDemoFocusReport {
            focusDemoReport
        } else {
            focusDeviceActivityReceipt
        }
    }

    @ViewBuilder
    private var focusDeviceActivityReceipt: some View {
        switch focusModeService.authorizationStatus {
        case .approved:
            DeviceActivityReport(.focusInsightsReceipt, filter: focusInsightsFilter)
                .frame(height: focusReportHeight)
                .id(selectedRange)
                .transition(focusRangeReportTransition)
                .animation(.smooth(duration: 0.50), value: selectedRange)
                .onAppear {
                    persistFocusReceiptPushbackDefaults()
                }
        case .notDetermined:
            focusScreenTimeFallback(
                title: "Connect Screen Time",
                subtitle: "See what pulled you back and what Memo protected.",
                canRequest: true
            )
        case .denied:
            focusScreenTimeFallback(
                title: "Screen Time is off",
                subtitle: "Turn it on in Settings to see your Focus receipt.",
                canRequest: false
            )
        @unknown default:
            focusScreenTimeFallback(
                title: "Screen Time unavailable",
                subtitle: "Memo needs permission before it can show app-level receipts.",
                canRequest: false
            )
        }
    }

    private var focusRangeReportTransition: AnyTransition {
        let insertionEdge: Edge = rangeTransitionDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = rangeTransitionDirection > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private func persistFocusReceiptPushbackDefaults() {
        let snapshot = focusSnapshot
        let defaults = UserDefaults(suiteName: "group.com.memori.shared") ?? .standard
        defaults.set(snapshot.protectedMinutes, forKey: "focus_receipt_protected_minutes")
        defaults.set(snapshot.unlockReps, forKey: "focus_receipt_unlock_reps")
        defaults.set(snapshot.blockedAttempts, forKey: "focus_receipt_blocked_attempts")
        defaults.set(snapshot.targetCount, forKey: "focus_receipt_target_count")
        defaults.set(Date(), forKey: "focus_receipt_pushback_updated_at")
    }

    private var focusReportHeight: CGFloat {
        switch selectedRange {
        case .today: return 760
        case .week: return 880
        case .month: return 880
        }
    }

    private var focusMemoPushbackLine: some View {
        let snapshot = focusSnapshot

        return VStack(spacing: 0) {
            thinDivider

            focusMemoPushbackTextView(for: snapshot)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
        }
        .padding(.bottom, 118)
    }

    private func focusMemoPushbackTextView(for snapshot: FocusInsightSnapshot) -> Text {
        guard snapshot.targetCount > 0 else {
            return Text("No targets locked yet · Pick targets so Memo can show pushback")
                .foregroundStyle(AppColors.textSecondary)
        }

        let blocks = snapshot.blockedAttempts == 1 ? "1 block" : "\(snapshot.blockedAttempts) blocks"
        let targets = snapshot.targetCount == 1 ? "1 target" : "\(snapshot.targetCount) targets"
        return Text("Memo pushed back · ")
            .foregroundStyle(AppColors.textSecondary)
            + Text(formatProtectedMinutes(snapshot.protectedMinutes))
            .foregroundStyle(AppColors.mint)
            + Text(" protected · \(snapshot.unlockReps) unlock reps · \(blocks) · \(targets)")
            .foregroundStyle(AppColors.textSecondary)
    }

    private func focusScreenTimeFallback(title: String, subtitle: String, canRequest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if canRequest {
                Button {
                    Task { await focusModeService.requestAuthorization() }
                } label: {
                    Text("Connect Screen Time")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(AppColors.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
    }

    private var focusDemoReport: some View {
        VStack(alignment: .leading, spacing: 18) {
            focusHistoryRail
            focusReportSummaryPanel
            focusFeedLoopChart
            focusDemoOffenders
            focusMemoPushbackPanel
        }
        .padding(.bottom, 118)
    }

    private var focusReportSummaryPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                focusSummaryMetric(label: "TOTAL", value: "20h 54m", suffix: nil, labelColor: AppColors.accent)
                verticalSummaryDivider
                focusSummaryMetric(label: "DAILY AVG", value: "2h 59m", suffix: "/ day", labelColor: AppColors.accent)
            }

            Rectangle()
                .fill(AppColors.cardBorder.opacity(0.30))
                .frame(height: 1)
                .padding(.horizontal, 8)

            HStack(spacing: 0) {
                focusSummaryMetric(label: "PEAK PULL", value: "Sat · 4h 2m", suffix: nil, labelColor: AppColors.coral)
                verticalSummaryDivider
                focusSummaryMetric(label: "PICKUPS", value: "845", suffix: "· 120/day", labelColor: AppColors.mint)
            }

            Rectangle()
                .fill(AppColors.cardBorder.opacity(0.30))
                .frame(height: 1)
                .padding(.horizontal, 8)

            Text("Feed tried hardest on Sat.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppColors.accent.opacity(0.36),
                            AppColors.mint.opacity(0.30),
                            AppColors.coral.opacity(0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func focusSummaryMetric(label: String, value: String, suffix: String?, labelColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(labelColor)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                if let suffix {
                    Text(suffix)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38)
    }

    private var verticalSummaryDivider: some View {
        Rectangle()
            .fill(AppColors.cardBorder.opacity(0.38))
            .frame(width: 1, height: 36)
    }

    private var focusMemoImpactReceipt: some View {
        let snapshot = focusSnapshot
        let blockText = snapshot.blockedAttempts == 1 ? "1 block" : "\(snapshot.blockedAttempts) blocks"
        let targetText = snapshot.targetCount == 1 ? "1 target locked" : "\(snapshot.targetCount) targets locked"

        return Text("\(formatProtectedMinutes(snapshot.protectedMinutes)) protected  ·  \(snapshot.unlockReps) unlock reps  ·  \(blockText)  ·  \(targetText)")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .padding(.vertical, 2)
    }

    private var focusMemoPushbackPanel: some View {
        let snapshot = focusSnapshot
        let blockText = snapshot.blockedAttempts == 1 ? "1 block" : "\(snapshot.blockedAttempts) blocks"

        return VStack(alignment: .leading, spacing: 12) {
            Text("Memo Pushback")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.mint)

            HStack(spacing: 10) {
                focusPushbackMetric(
                    value: formatProtectedMinutes(snapshot.protectedMinutes),
                    label: "protected",
                    color: AppColors.mint
                )

                focusPushbackMetric(
                    value: "\(snapshot.unlockReps)",
                    label: snapshot.unlockReps == 1 ? "unlock rep" : "unlock reps",
                    color: .primary
                )

                focusPushbackMetric(
                    value: blockText,
                    label: "blocked",
                    color: AppColors.coral
                )
            }
        }
        .padding(14)
        .background(AppColors.cardSurface.opacity(0.54), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.mint.opacity(0.30), lineWidth: 1)
        )
    }

    private func focusPushbackMetric(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var focusRangeLabel: String {
        switch selectedRange {
        case .today: return "Today"
        case .week: return "This week"
        case .month: return "This month"
        }
    }

    private var focusRangeScreenTimeSeconds: TimeInterval {
        switch selectedRange {
        case .today:
            return focusSnapshot.screenTimeSeconds
        case .week:
            let activeHours = focusSnapshot.weeklyScreenTimeHours.filter { $0 > 0 }
            guard !activeHours.isEmpty else { return focusSnapshot.screenTimeSeconds }
            return average(activeHours) * 3600
        case .month:
            let activeHours = focusSnapshot.weeklyScreenTimeHours.filter { $0 > 0 }
            let currentAverage = activeHours.isEmpty ? focusSnapshot.screenTimeSeconds : average(activeHours) * 3600
            guard let baseline = focusSnapshot.baselineDailyAverageSeconds else { return currentAverage }
            return max(currentAverage, baseline - (48 * 60))
        }
    }

    private var focusRangePickups: Int {
        switch selectedRange {
        case .today:
            return focusSnapshot.pickups
        case .week:
            return max(focusSnapshot.pickups, focusSnapshot.pickups * 5)
        case .month:
            return max(focusSnapshot.pickups, focusSnapshot.pickups * 22)
        }
    }

    private var focusHistoryItems: [FocusHistoryItem] {
        switch selectedRange {
        case .today:
            let values = paddedFocusHours(count: 7)
            let yesterday = values.indices.contains(values.count - 2) ? values[values.count - 2] : 0
            let today = max(focusSnapshot.screenTimeSeconds / 3600, values.last ?? 0)
            return [
                FocusHistoryItem(id: 0, title: "Yesterday", subtitle: formatHoursCompact(yesterday), hours: yesterday),
                FocusHistoryItem(id: 1, title: "Today", subtitle: formatHoursCompact(today), hours: today)
            ]
        case .week:
            let values = paddedFocusHours(count: 7)
            let labels = lastSevenDayLabels()
            return values.enumerated().map { index, hours in
                FocusHistoryItem(id: index, title: labels[index].day, subtitle: labels[index].date, hours: hours)
            }
        case .month:
            let activeAverage = max(average(focusSnapshot.weeklyScreenTimeHours.filter { $0 > 0 }), focusSnapshot.screenTimeSeconds / 3600)
            let baseline = max((focusSnapshot.baselineDailyAverageSeconds ?? focusSnapshot.screenTimeSeconds) / 3600, activeAverage)
            let values = [
                baseline,
                baseline * 0.88 + activeAverage * 0.12,
                baseline * 0.68 + activeAverage * 0.32,
                activeAverage
            ]
            return values.enumerated().map { index, hours in
                FocusHistoryItem(id: index, title: "Week \(index + 1)", subtitle: formatHoursCompact(hours), hours: hours)
            }
        }
    }

    private var focusSelectedHistoryItem: FocusHistoryItem? {
        let items = focusHistoryItems
        guard !items.isEmpty else { return nil }
        let index = min(max(selectedFocusHistoryIndex, 0), items.count - 1)
        return items[index]
    }

    private var focusSelectedHistoryTitle: String {
        guard let item = focusSelectedHistoryItem else { return focusRangeLabel }
        if selectedRange == .week, item.id == focusHistoryItems.count - 1 { return "Today" }
        return item.title
    }

    private var focusSelectedScreenTimeSeconds: TimeInterval {
        guard let item = focusSelectedHistoryItem else { return focusRangeScreenTimeSeconds }
        return max(0, item.hours * 3600)
    }

    private var focusSelectedPickups: Int {
        let baseHours = max(focusSnapshot.screenTimeSeconds / 3600, 0.1)
        let selectedHours = max(focusSelectedScreenTimeSeconds / 3600, 0)
        let ratio = max(0.35, min(1.55, selectedHours / baseHours))
        return max(0, Int((Double(focusSnapshot.pickups) * ratio).rounded()))
    }

    private var focusHistoryRail: some View {
        let items = focusHistoryItems
        let averageHours = max(average(items.map(\.hours).filter { $0 > 0 }), 0.1)
        let selectedIndex = min(max(selectedFocusHistoryIndex, 0), max(items.count - 1, 0))

        return HStack(spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            selectedFocusHistoryIndex = index
                        }
                    } label: {
                        focusHistoryTile(
                            item: item,
                            isSelected: index == selectedIndex,
                            averageHours: averageHours
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
    }

    private func focusHistoryTile(item: FocusHistoryItem, isSelected: Bool, averageHours: Double) -> some View {
        let isLow = item.hours <= averageHours
        let tint = item.hours <= 0 ? AppColors.textSecondary : (isLow ? AppColors.mint : AppColors.coral)
        let maxHours = max(focusHistoryItems.map(\.hours).max() ?? 1, 1)
        let totalBarHeight = max(7, min(34, CGFloat(item.hours / maxHours) * 34))
        let overAverageHeight = max(0, min(totalBarHeight * 0.34, CGFloat(max(item.hours - averageHours, 0) / maxHours) * 34))
        let baseHeight = max(5, totalBarHeight - overAverageHeight)

        return VStack(spacing: 6) {
            Text(indexTitle(for: item))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? .primary : AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(item.subtitle)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? .primary : AppColors.textSecondary.opacity(0.86))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            VStack(spacing: 0) {
                if overAverageHeight > 0 {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColors.coral.opacity(isSelected ? 0.95 : 0.74))
                        .frame(width: isSelected ? 18 : 15, height: overAverageHeight)
                } else if isLow && item.hours > 0 {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColors.mint.opacity(isSelected ? 0.95 : 0.70))
                        .frame(width: isSelected ? 18 : 15, height: 6)
                }

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.periwinkle.opacity(isSelected ? 0.92 : 0.68),
                                AppColors.accent.opacity(isSelected ? 0.82 : 0.54)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: isSelected ? 18 : 15, height: baseHeight)
            }
            .frame(height: 38, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.cardSurface.opacity(0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(tint.opacity(0.78), lineWidth: 1.2)
                    )
            }
        }
    }

    private func indexTitle(for item: FocusHistoryItem) -> String {
        if selectedRange == .week, item.id == focusHistoryItems.count - 1 { return "TODAY" }
        return item.title.uppercased()
    }

    private var focusFeedLoopChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Feed Pull Per Day")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Text("avg 2h 59m")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.mint)
            }

            focusChartPlot
        }
        .padding(.vertical, 2)
    }

    private var focusChartPlot: some View {
        GeometryReader { proxy in
            let values = focusChartDisplayHours
            let yMax = max(5.0, ceil(values.max() ?? 1))
            let width = proxy.size.width
            let height = proxy.size.height
            let plotLeft: CGFloat = 30
            let plotRight: CGFloat = 10
            let plotBottom: CGFloat = 28
            let plotTop: CGFloat = 34
            let plotHeight = max(1, height - plotTop - plotBottom)
            let averageHours = min(2.98, yMax)
            let averageY = plotTop + plotHeight * (1 - min(max(averageHours / yMax, 0), 1))
            let peakIndex = focusChartPeakIndex(values)
            let lowIndex = focusChartLowIndex(values)
            let selectedIndex = min(max(selectedFocusHistoryIndex, 0), max(values.count - 1, 0))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColors.pageBgDark.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppColors.cardBorder.opacity(0.64), lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    ForEach([5, 4, 3, 2, 1, 0], id: \.self) { hour in
                        HStack(spacing: 8) {
                            Text(hour == 0 ? "0" : "\(hour)h")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.78))
                                .frame(width: 22, alignment: .leading)
                            if hour == 0 {
                                Rectangle()
                                    .fill(AppColors.cardBorder.opacity(0.24))
                                    .frame(height: 1)
                            } else {
                                Rectangle()
                                    .fill(AppColors.cardBorder.opacity(0.12))
                                    .frame(height: 1)
                            }
                        }
                        if hour > 0 { Spacer(minLength: 0) }
                    }
                }
                .padding(.leading, 11)
                .padding(.trailing, 12)
                .padding(.top, plotTop)
                .padding(.bottom, plotBottom)

                Path { path in
                    path.move(to: CGPoint(x: plotLeft, y: averageY))
                    path.addLine(to: CGPoint(x: width - plotRight, y: averageY))
                }
                .stroke(
                    AppColors.mint.opacity(0.72),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [7, 8])
                )

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, hours in
                        let selected = index == selectedIndex
                        let barHeight = max(hours > 0 ? 10 : 4, CGFloat(hours / yMax) * plotHeight)
                        let overAverageHours = max(0, hours - averageHours)
                        let coralHeight = min(barHeight * 0.36, CGFloat(overAverageHours / yMax) * plotHeight)
                        let baseHeight = max(6, barHeight - coralHeight)
                        let isWonBack = index == lowIndex && hours > 0

                        VStack(spacing: 7) {
                            ZStack {
                                if index == peakIndex {
                                    focusChartBadge("peak \(focusChartValueLabel(hours, index: index))", color: AppColors.coral)
                                } else if isWonBack {
                                    focusChartBadge("won \(focusChartValueLabel(hours, index: index))", color: AppColors.mint)
                                } else if selected {
                                    Text(focusChartValueLabel(hours, index: index))
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .monospacedDigit()
                                }
                            }
                            .frame(height: 24)

                            ZStack(alignment: .bottom) {
                                VStack(spacing: 0) {
                                    if coralHeight > 0 {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(AppColors.coral.opacity(selected ? 0.98 : 0.86))
                                            .frame(width: selected ? 29 : 24, height: coralHeight)
                                    } else if isWonBack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(AppColors.mint.opacity(selected ? 0.98 : 0.82))
                                            .frame(width: selected ? 29 : 24, height: 9)
                                    }

                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    AppColors.periwinkle.opacity(selected ? 1.00 : 0.88),
                                                    AppColors.accent.opacity(selected ? 0.92 : 0.72)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: selected ? 29 : 24, height: baseHeight)
                                }
                            }
                            .frame(height: plotHeight, alignment: .bottom)

                            Text(focusChartBarLabel(index: index, total: values.count))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(selected ? .primary : AppColors.textSecondary.opacity(0.84))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.18)) {
                                selectedFocusHistoryIndex = index
                            }
                        }
                    }
                }
                .padding(.leading, plotLeft)
                .padding(.trailing, plotRight)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
        }
        .frame(height: 262)
    }

    private func focusChartBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .monospacedDigit()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.58), lineWidth: 1))
            .lineLimit(1)
            .minimumScaleFactor(0.70)
    }

    private func focusChartPeakIndex(_ values: [Double]) -> Int {
        values.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
    }

    private func focusChartLowIndex(_ values: [Double]) -> Int {
        values.enumerated()
            .filter { $0.element > 0 }
            .min(by: { $0.element < $1.element })?.offset ?? 0
    }

    private var focusChartDisplayHours: [Double] {
        switch selectedRange {
        case .today:
            let total = max(focusSelectedScreenTimeSeconds / 3600, 0.1)
            return [0.10, 0.18, 0.08, 0.38, 0.64, 0.42, 0.16, 0.24, 0.74, 0.32].map { total * $0 }
        case .week:
            return [2.25, 3.83, 3.85, 4.02, 0.72, 2.20, 4.20]
        case .month:
            return focusHistoryItems.map(\.hours)
        }
    }

    private var focusChartRead: String {
        let values = focusChartDisplayHours.filter { $0 > 0 }
        guard let selected = focusSelectedHistoryItem, values.count > 1 else { return "building history" }
        let avg = average(values)
        if selected.hours <= avg { return "below average" }
        return "feed pulled hard"
    }

    private var focusChartReadColor: Color {
        focusChartRead == "feed pulled hard" ? AppColors.coral : AppColors.mint
    }

    private func focusChartBarLabel(index: Int, total: Int) -> String {
        switch selectedRange {
        case .today:
            return index == 0 ? "12a" : (index == total - 1 ? "now" : "")
        case .week:
            let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return labels.indices.contains(index) ? labels[index] : ""
        case .month:
            return "W\(index + 1)"
        }
    }

    private func paddedFocusHours(count: Int) -> [Double] {
        let raw = focusSnapshot.weeklyScreenTimeHours
        let padded = Array(repeating: 0, count: max(0, count - raw.count)) + raw.suffix(count)
        return Array(padded.suffix(count))
    }

    private func lastSevenDayLabels() -> [(day: String, date: String)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { offset in
            let dayOffset = offset - 6
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return (
                day: date.formatted(.dateTime.weekday(.abbreviated)),
                date: date.formatted(.dateTime.day())
            )
        }
    }

    private func formatHoursCompact(_ hours: Double) -> String {
        guard hours > 0 else { return "--" }
        let totalMinutes = Int((hours * 60).rounded())
        let hourPart = totalMinutes / 60
        let minutePart = totalMinutes % 60
        if hourPart == 0 { return "\(minutePart)m" }
        if minutePart == 0 { return "\(hourPart)h" }
        return "\(hourPart)h \(minutePart)m"
    }

    private func focusChartValueLabel(_ hours: Double, index: Int) -> String {
        if selectedRange == .week {
            let values = ["2h 15m", "3h 50m", "3h 51m", "4h 1m", "43m", "2h 12m", "4h 2m"]
            return values.indices.contains(index) ? values[index] : formatHoursCompact(hours)
        }
        return formatHoursCompact(hours)
    }

    private func demoReceiptLine(label: String, value: String, caption: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 92, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.80)

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(caption)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary.opacity(0.75))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }

    private func demoTopPullLine(_ offender: FocusInsightOffender, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("Top pull")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 92, alignment: .leading)

            offenderIcon(offender, index: index, size: 34)

            Text(offender.name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatReceiptDuration(offender.durationSeconds))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.coral)
                    .monospacedDigit()
                Text("\(offenderShare(offender, totalSeconds: focusSnapshot.screenTimeSeconds)) of today")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.72))
            }
        }
        .padding(.vertical, 13)
    }

    private var focusDemoTrendTrace: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Feed trace")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text("below average")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.mint)
            }

            GeometryReader { proxy in
                let values = focusSnapshot.weeklyScreenTimeHours
                let maxValue = max(values.max() ?? 1, 1)
                let width = proxy.size.width
                let height = proxy.size.height
                let step = values.count > 1 ? width / CGFloat(values.count - 1) : width

                ZStack(alignment: .bottomLeading) {
                    Path { path in
                        guard let first = values.first else { return }
                        path.move(to: CGPoint(x: 0, y: height * (1 - min(first / maxValue, 1))))
                        for index in values.indices.dropFirst() {
                            let normalized = min(max(values[index] / maxValue, 0.08), 1)
                            path.addLine(to: CGPoint(x: CGFloat(index) * step, y: height * (1 - normalized)))
                        }
                    }
                    .stroke(AppColors.periwinkle.opacity(0.80), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    Rectangle()
                        .fill(AppColors.cardBorder.opacity(0.35))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 42)
        }
        .padding(.vertical, 8)
    }

    private var focusDemoOffenders: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Top Pullers")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Text("TIME")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(AppColors.coral)

                Text("OPENS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(AppColors.textSecondary)

                Text("SHARE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(AppColors.coral)
            }

            VStack(spacing: 0) {
                ForEach(Array(focusDisplayOffenders.prefix(4).enumerated()), id: \.element.id) { index, offender in
                    focusOffenderRow(offender, index: index)
                    if index < min(focusDisplayOffenders.count, 4) - 1 {
                        thinDivider
                    }
                }
            }
        }
        .padding(14)
        .background(AppColors.cardSurface.opacity(0.48), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.cardBorder.opacity(0.56), lineWidth: 1)
        )
    }

    private var focusDisplayOffenders: [FocusInsightOffender] {
        var offenders = focusSnapshot.offenders
        if !offenders.contains(where: { $0.name.localizedCaseInsensitiveContains("YouTube") }) {
            offenders.append(
                FocusInsightOffender(
                    name: "YouTube",
                    durationSeconds: TimeInterval(97 * 60),
                    opens: 16,
                    iconAssetName: "logo-youtube"
                )
            )
        }
        return offenders
    }

    private var focusBeforeAfterSection: some View {
        let snapshot = focusSnapshot

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.baselineDailyAverageSeconds == nil ? "Building your baseline" : "This week with Memo")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(focusBaselineRead)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            focusTransformationScene

            HStack(spacing: 12) {
                focusMetric("Screen time", value: formatReceiptDuration(snapshot.screenTimeSeconds))
                verticalDivider
                focusMetric("Pickups", value: "\(snapshot.pickups)")
                verticalDivider
                focusMetric("Protected", value: formatProtectedMinutes(snapshot.protectedMinutes))
            }
        }
    }

    private var memoImpactSection: some View {
        let snapshot = focusSnapshot

        return HStack(spacing: 0) {
            Text("\(formatProtectedMinutes(snapshot.protectedMinutes)) protected  ·  \(snapshot.unlockReps) unlock reps  ·  \(snapshot.targetCount) target\(snapshot.targetCount == 1 ? "" : "s") locked")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var focusTransformationScene: some View {
        let snapshot = focusSnapshot
        let currentSeconds = currentFocusAverageSeconds
        let hasBaseline = snapshot.baselineDailyAverageSeconds != nil
        let beforeSeconds = snapshot.baselineDailyAverageSeconds ?? max(currentSeconds, 4 * 3600)
        let currentHours = max(currentSeconds / 3600, 0.35)
        let beforeHours = max(beforeSeconds / 3600, currentHours)
        let maxHours = max(beforeHours, currentHours, 4)

        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 18) {
                focusComparisonColumn(
                    title: hasBaseline ? "Before Memo" : "Baseline",
                    value: hasBaseline ? formatReceiptDuration(beforeSeconds) : "collecting",
                    bars: focusBars(seedHours: beforeHours, softer: !hasBaseline),
                    maxHours: maxHours,
                    tint: hasBaseline ? AppColors.coral : AppColors.textSecondary
                )

                Rectangle()
                    .fill(AppColors.cardBorder.opacity(0.34))
                    .frame(width: 1)
                    .padding(.vertical, 10)

                focusComparisonColumn(
                    title: hasBaseline ? "This week" : "This week",
                    value: formatReceiptDuration(currentSeconds),
                    bars: focusBars(seedHours: currentHours, softer: false),
                    maxHours: maxHours,
                    tint: AppColors.mint
                )
            }

            Text(focusTimeBackLine)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(hasBaseline ? AppColors.mint : AppColors.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.cardSurface.opacity(0.48))
                .overlay(
                    LinearGradient(
                        colors: [
                            AppColors.coral.opacity(hasBaseline ? 0.10 : 0.03),
                            AppColors.mint.opacity(0.08),
                            AppColors.pageBgDark.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.cardBorder.opacity(0.28), lineWidth: 1)
        )
    }

    private func focusComparisonColumn(title: String, value: String, bars: [Double], maxHours: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                Text(value)
                    .font(.system(size: value == "collecting" ? 18 : 24, weight: .black, design: .rounded))
                    .foregroundStyle(value == "collecting" ? AppColors.textSecondary : .primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            stackedMiniBars(values: bars, maxHours: maxHours, tint: tint)
                .frame(height: 64)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stackedMiniBars(values: [Double], maxHours: Double, tint: Color) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let height = max(8, CGFloat(value / maxHours) * 58)
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(tint.opacity(index == values.count - 1 ? 0.82 : 0.66))
                        .frame(height: height * 0.36)
                    Rectangle()
                        .fill(AppColors.periwinkle.opacity(0.60))
                        .frame(height: height * 0.34)
                    Rectangle()
                        .fill(AppColors.accent.opacity(0.64))
                        .frame(height: height * 0.30)
                }
                .frame(width: 13, height: height, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .opacity(value <= 0 ? 0.32 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.cardBorder.opacity(0.22))
                .frame(height: 1)
        }
    }

    private func focusMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var focusOffendersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most pulled")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            if focusSnapshot.offenders.isEmpty {
                quietEmptyText("Offenders appear here once Screen Time exposes app activity.")
                    .frame(maxWidth: .infinity, minHeight: 54)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(focusSnapshot.offenders.enumerated()), id: \.element.id) { index, offender in
                        focusOffenderRow(offender)

                        if index < focusSnapshot.offenders.count - 1 {
                            thinDivider
                        }
                    }
                }
            }
        }
    }

    private func focusOffenderRow(_ offender: FocusInsightOffender, index: Int? = nil) -> some View {
        HStack(spacing: 12) {
            offenderIcon(offender, index: index)

            Text(offender.name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer()

            Text(formatReceiptDuration(offender.durationSeconds))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.coral)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text("\(offender.opens) opens")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .monospacedDigit()
                .frame(width: 62, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(offenderShare(offender, totalSeconds: focusSnapshot.screenTimeSeconds))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.coral)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }

    private var focusReceiptRead: String {
        let snapshot = focusSnapshot

        if let offender = focusDisplayOffenders.first, snapshot.screenTimeSeconds > 0 {
            return "\(offender.name) is the top pull. Screen Time stays on your phone."
        }

        if snapshot.protectedMinutes > 0 {
            return "Memo pushed back \(formatProtectedMinutes(snapshot.protectedMinutes)). Screen Time stays on your phone."
        }

        return "Connect Screen Time to see what pulled you back."
    }

    private var focusReceiptHeroData: FocusReceiptHeroData {
        _ = focusReceiptRefreshToken
        let defaults = UserDefaults(suiteName: "group.com.memori.shared") ?? .standard
        let storedName = defaults.string(forKey: "focus_receipt_top_app_name")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackOffender = focusSnapshot.offenders.first
        let topAppName = storedName?.isEmpty == false
            ? (storedName ?? "Big Social")
            : (fallbackOffender?.name ?? "Big Social")
        let topAppSeconds = defaults.double(forKey: "focus_receipt_top_app_seconds")
        let totalPullSeconds = defaults.double(forKey: "focus_receipt_screen_time_seconds")
        let latestPullSeconds = defaults.double(forKey: "focus_receipt_latest_day_seconds")
        let averagePullSeconds = defaults.double(forKey: "focus_receipt_daily_average_seconds")
        let pickups = defaults.integer(forKey: "focus_receipt_pickups")

        return FocusReceiptHeroData(
            topAppName: topAppName,
            topAppSeconds: topAppSeconds > 0 ? topAppSeconds : (fallbackOffender?.durationSeconds ?? 0),
            totalPullSeconds: totalPullSeconds > 0 ? totalPullSeconds : focusSnapshot.screenTimeSeconds,
            latestPullSeconds: latestPullSeconds > 0 ? latestPullSeconds : focusSnapshot.screenTimeSeconds,
            averagePullSeconds: averagePullSeconds,
            pickups: pickups > 0 ? pickups : focusSnapshot.pickups
        )
    }

    private func focusHeroMood(for hero: FocusReceiptHeroData) -> MascotRiveMood {
        guard hero.latestPullSeconds > 0, hero.averagePullSeconds > 0 else { return .neutral }
        if hero.latestPullSeconds <= hero.averagePullSeconds * 0.90 { return .happy }
        if hero.latestPullSeconds >= hero.averagePullSeconds * 1.10 { return .sad }
        return .neutral
    }

    private func focusHeroMoodLabel(for hero: FocusReceiptHeroData) -> String {
        switch focusHeroMood(for: hero) {
        case .happy: return "below avg"
        case .neutral: return "near avg"
        case .sad: return "above avg"
        }
    }

    private func focusHeroMascotAsset(for hero: FocusReceiptHeroData) -> String {
        switch focusHeroMood(for: hero) {
        case .happy: return "mascot-unlocked"
        case .neutral: return "mascot-thinking"
        case .sad: return "mascot-locked-sad"
        }
    }

    private func socialLogoAsset(for appName: String) -> String? {
        let name = appName.lowercased()
        if name.contains("tiktok") { return "logo-tiktok" }
        if name.contains("instagram") { return "logo-instagram" }
        if name.contains("youtube") { return "logo-youtube" }
        if name.contains("reddit") { return "logo-reddit" }
        if name.contains("snap") { return "logo-snapchat" }
        if name.contains("discord") { return "logo-discord" }
        if name == "x" || name.contains("twitter") { return "logo-x" }
        if name.contains("facebook") { return "logo-facebook" }
        if name.contains("threads") { return "logo-threads" }
        if name.contains("twitch") { return "logo-twitch" }
        if name.contains("pinterest") { return "logo-pinterest" }
        if name.contains("bluesky") { return "logo-bluesky" }
        return nil
    }

    private var focusStatusTitle: String {
        if focusModeService.blockedAppCount == 0 { return "Not set up" }
        if focusModeService.isTemporarilyUnlocked { return "Unlocked" }
        if focusModeService.isEnabled { return "Blocking" }
        return "Off duty"
    }

    private var focusPatternRead: String {
        let snapshot = focusSnapshot
        if let offender = snapshot.offenders.first, snapshot.screenTimeSeconds > 0 {
            return "\(offender.name) is taking \(offenderShare(offender, totalSeconds: snapshot.screenTimeSeconds)) of today's phone time."
        }
        if snapshot.blockedAttempts > 0 {
            return "Memo blocked \(snapshot.blockedAttempts) re-entry attempts today."
        }
        if snapshot.pickups > 0 {
            return "You checked your phone \(snapshot.pickups) times today."
        }
        return "No feed loop detected yet. Memo's waiting for a real signal."
    }

    private func sectionEyebrow(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(2)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }

    private func makeFocusSnapshot() -> FocusInsightSnapshot {
        #if DEBUG
        if let previewFocusSnapshot {
            return previewFocusSnapshot
        }

        let defaults = UserDefaults(suiteName: "group.com.memori.shared") ?? .standard
        if defaults.bool(forKey: "focus_demo_data_enabled") {
            let names = defaults.stringArray(forKey: "focus_demo_offender_names") ?? []
            let seconds = defaults.array(forKey: "focus_demo_offender_seconds") as? [Int] ?? []
            let opens = defaults.array(forKey: "focus_demo_offender_opens") as? [Int] ?? []
            let icons = defaults.stringArray(forKey: "focus_demo_offender_icon_assets") ?? []
            let offenders = names.enumerated().map { index, name in
                FocusInsightOffender(
                    name: name,
                    durationSeconds: TimeInterval(seconds.indices.contains(index) ? seconds[index] : 0),
                    opens: opens.indices.contains(index) ? opens[index] : 0,
                    iconAssetName: icons.indices.contains(index) ? icons[index] : nil
                )
            }

            return FocusInsightSnapshot(
                screenTimeSeconds: TimeInterval(defaults.integer(forKey: "focus_demo_screen_time_seconds")),
                pickups: defaults.integer(forKey: "focus_demo_pickups"),
                weeklyScreenTimeHours: defaults.array(forKey: "focus_demo_weekly_screen_time_hours") as? [Double] ?? [],
                baselineDailyAverageSeconds: TimeInterval(6 * 3600 + 32 * 60),
                protectedMinutes: defaults.integer(forKey: "focus_demo_protected_minutes"),
                unlockReps: defaults.integer(forKey: "focus_demo_unlock_reps"),
                blockedAttempts: defaults.integer(forKey: "focus_demo_blocked_attempts"),
                targetCount: defaults.integer(forKey: "focus_demo_target_count"),
                passMinutes: defaults.integer(forKey: "focus_demo_pass_minutes"),
                offenders: offenders,
                isDemoData: true
            )
        }
        #endif

        let protectedMinutes = focusModeService.weeklyBlockedMinutes
        let passMinutes = focusModeService.unlockDuration
        let attempts = focusModeService.dailyAttemptCount
        let targetCount = focusModeService.blockedAppCount
        let fallbackHours = targetCount > 0 || attempts > 0
            ? [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
            : []

        return FocusInsightSnapshot(
            screenTimeSeconds: 0,
            pickups: 0,
            weeklyScreenTimeHours: fallbackHours,
            baselineDailyAverageSeconds: nil,
            protectedMinutes: protectedMinutes,
            unlockReps: attempts,
            blockedAttempts: attempts,
            targetCount: targetCount,
            passMinutes: passMinutes,
            offenders: [],
            isDemoData: false
        )
    }

    private func refreshFocusSnapshot() {
        focusSnapshot = makeFocusSnapshot()
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var currentFocusAverageSeconds: TimeInterval {
        if focusSnapshot.screenTimeSeconds > 0 {
            return focusSnapshot.screenTimeSeconds
        }

        let nonZeroHours = focusSnapshot.weeklyScreenTimeHours.filter { $0 > 0 }
        guard !nonZeroHours.isEmpty else { return 0 }
        return average(nonZeroHours) * 3600
    }

    private var focusBaselineRead: String {
        guard focusSnapshot.baselineDailyAverageSeconds != nil else {
            return "Memo is tracking your first week before it calls a win."
        }

        return "Your feed loop is lower than your starting average."
    }

    private var focusTimeBackLine: String {
        guard let baseline = focusSnapshot.baselineDailyAverageSeconds else {
            return "Building a real before/after baseline."
        }

        let recovered = max(0, baseline - currentFocusAverageSeconds)
        guard recovered > 0 else {
            return "Memo is still learning your loop."
        }

        return "\(formatReceiptDuration(recovered)) back per day"
    }

    private func focusBars(seedHours: Double, softer: Bool) -> [Double] {
        let multipliers = softer
            ? [0.25, 0.32, 0.28, 0.20, 0.18]
            : [0.86, 1.04, 0.92, 0.74, 0.62]
        return multipliers.map { max(0.12, seedHours * $0) }
    }

    private var focusChartHours: [Double] {
        if effectiveFocusRange == .today {
            let hours = focusSnapshot.screenTimeSeconds / 3600
            return hours > 0 ? [hours] : []
        }
        return focusSnapshot.weeklyScreenTimeHours
    }

    private func focusChartMaxHour(for values: [Double]) -> Double {
        let maxValue = values.max() ?? 1
        return max(ceil(maxValue), 4)
    }

    private func focusYAxisValues(maxHour: Double) -> [Double] {
        let mid = maxHour / 2
        return [0, mid, maxHour]
    }

    private func focusAxisLabel(_ hour: Double) -> String {
        if hour == 0 { return "0" }
        return "\(Int(hour.rounded()))h"
    }

    private func focusDayLabel(index: Int, count: Int) -> String {
        guard count > 0 else { return "" }
        if index == count - 1 { return "Today" }
        let calendar = Calendar.current
        let daysBack = count - 1 - index
        let date = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        return date.formatted(.dateTime.weekday(.narrow))
    }

    private func offenderShare(_ offender: FocusInsightOffender, totalSeconds: TimeInterval) -> String {
        guard totalSeconds > 0 else { return "0%" }
        let percent = Int((offender.durationSeconds / totalSeconds * 100).rounded())
        return "\(percent)%"
    }

    @ViewBuilder
    private func offenderIcon(_ offender: FocusInsightOffender, index: Int? = nil) -> some View {
        offenderIcon(offender, index: index, size: 42)
    }

    @ViewBuilder
    private func offenderIcon(_ offender: FocusInsightOffender, index: Int? = nil, size: CGFloat) -> some View {
        let appTokens = Array(focusModeService.activitySelection.applicationTokens)
        let categoryTokens = Array(focusModeService.activitySelection.categoryTokens)

        if let index, appTokens.indices.contains(index) {
            Label(appTokens[index])
                .labelStyle(.iconOnly)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        } else if let index, categoryTokens.indices.contains(index - appTokens.count) {
            Label(categoryTokens[index - appTokens.count])
                .labelStyle(.iconOnly)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        } else if let assetName = offender.iconAssetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(AppColors.cardSurface.opacity(0.68))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "app.fill")
                        .font(.system(size: size * 0.34, weight: .bold))
                        .foregroundStyle(AppColors.textSecondary)
                )
        }
    }
    private func formatReceiptDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    private func formatProtectedMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    // MARK: - 1. Brain Score Trendline

    private var trendlineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header label
            Text("BRAIN SCORE \u{00B7} \(selectedRange.rawValue)")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Large score + delta
            if let score = currentScore {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(score.brainScore)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    if isProUser, scoreDelta != 0 {
                        deltaLabel(value: scoreDelta, inverted: false)
                    }
                }
            }

            // Chart — Pro gets full chart, free gets blurred teaser
            if isProUser {
                if filteredScores.count >= 2 {
                    trendlineChart
                        .frame(height: 160)
                } else {
                    Text("Not enough data for this period")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            } else {
                // Free user: blurred chart teaser
                chartProTeaser
            }
        }
    }

    private var chartProTeaser: some View {
        ZStack {
            // Show actual line if data exists, otherwise a soft line-only preview.
            if filteredScores.count >= 2 {
                trendlineChart
                    .frame(height: 160)
                    .blur(radius: 8)
            } else {
                brainLinePreviewChart
                    .frame(height: 160)
                    .blur(radius: 8)
            }

            // Overlay
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)

                Text("Unlock detailed insights")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Button {
                    showingPaywall = true
                } label: {
                    Text("Go Pro")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppColors.accent, in: Capsule())
                }
            }
        }
        .frame(height: 160)
    }

    private var brainLinePreviewChart: some View {
        let previewScores = [604, 616, 611, 637, 648, 666, 681, 694, 707, 721]

        return Chart {
            ForEach(Array(previewScores.enumerated()), id: \.offset) { index, score in
                LineMark(
                    x: .value("Rep", index),
                    y: .value("Score", score)
                )
                .foregroundStyle(AppColors.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        .chartYScale(domain: 580...740)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.padding(.vertical, 16)
        }
    }

    private func localRangeChips(accent: Color) -> some View {
        HStack(spacing: 6) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    guard selectedRange != range else { return }
                    withAnimation(.snappy(duration: 0.18)) {
                        selectedRange = range
                        if selectedMode == .focus {
                            selectedFocusHistoryIndex = defaultFocusHistoryIndex(for: range)
                        }
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(selectedRange == range ? accent : AppColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            if selectedRange == range {
                                glassSelectedCapsule(color: accent)
                            }
                        }
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityLabel("\(range.rawValue) insights range")
                .accessibilityAddTraits(selectedRange == range ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .background(AppColors.pageBgDark.opacity(0.34), in: Capsule())
        .overlay(glassCapsuleStroke(opacity: 0.24))
    }

    private func defaultFocusHistoryIndex(for range: TimeRange) -> Int {
        switch range {
        case .today: return 1
        case .week: return 6
        case .month: return 3
        }
    }

    private var trendlineChart: some View {
        let chartData = filteredScores.sorted { $0.date < $1.date }
        let scores = chartData.map(\.brainScore)
        let rawMin = scores.min() ?? 0
        let rawMax = scores.max() ?? 1000
        let span = max(rawMax - rawMin, 1)
        // 50pt minimum padding or 40% of span — keeps line floating instead of hugging edges
        let padding = max(50, span * 2 / 5)
        let minScore = max(0, rawMin - padding)
        let maxScore = min(1000, rawMax + padding)
        let lastIndex = chartData.count - 1

        return Chart {
            ForEach(Array(chartData.enumerated()), id: \.element.id) { index, item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Score", item.brainScore)
                )
                .foregroundStyle(AppColors.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Score", item.brainScore)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(index == lastIndex ? 80 : 24)
            }
        }
        .chartYScale(domain: minScore...maxScore)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .padding(.top, 8)
                .padding(.trailing, 8)
                .padding(.bottom, 4)
        }
        .clipped()
    }

    // MARK: - 2. Stats Table

    private var statsTableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Column headers
            HStack {
                Text("METRIC")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if isProUser {
                    Text("VALUE \u{00B7} \u{0394}\(selectedRange.rawValue)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                } else {
                    Text("VALUE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }

            Divider().opacity(0.3)

            // Rows
            VStack(spacing: 0) {
                // Brain Score
                if let score = currentScore {
                    statsRow(
                        label: "Brain Score",
                        value: "\(score.brainScore) / 1000",
                        delta: isProUser ? scoreDelta : nil,
                        inverted: false
                    )
                    thinDivider
                }

                // Brain Age
                if let score = currentScore {
                    statsRow(
                        label: "Brain Age",
                        value: "\(score.brainAge) yrs",
                        delta: isProUser ? brainAgeDelta : nil,
                        inverted: true
                    )
                    thinDivider
                }

                // Best Rank (Pro only)
                if isProUser, let bestRank = bestPersonalRecord {
                    statsRow(
                        label: "Best Rank",
                        value: "\(bestRank.type.displayName) \u{00B7} \(personalBestDisplay(type: bestRank.type, value: bestRank.best))",
                        delta: nil,
                        inverted: false
                    )
                    thinDivider
                }

                // Streak
                if let user = user {
                    statsRow(
                        label: "Streak",
                        value: "\(user.currentStreak) days",
                        delta: nil,
                        inverted: false,
                        suffix: "best \(user.longestStreak)"
                    )
                    thinDivider
                }

                // Games Played
                statsRow(
                    label: "Games Played",
                    value: "\(user?.totalExercises ?? exercises.count)",
                    delta: nil,
                    inverted: false
                )

                // Time Trained (Pro only)
                if isProUser {
                    thinDivider
                    statsRow(
                        label: "Time Trained",
                        value: formatTotalTime(),
                        delta: nil,
                        inverted: false
                    )
                }
            }
        }
    }

    private func statsRow(label: String, value: String, delta: Int? = nil, inverted: Bool, suffix: String? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if let delta = delta, delta != 0 {
                    deltaLabel(value: delta, inverted: inverted)
                }

                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var thinDivider: some View {
        Divider().opacity(0.15)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppColors.cardBorder.opacity(0.35))
            .frame(height: 1)
    }

    // MARK: - 3. Cognitive Domains

    private var cognitiveDomainsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionEyebrow("COGNITIVE DOMAINS", color: AppColors.textSecondary)

            if let score = currentScore {
                VStack(spacing: 12) {
                    domainBar(label: "Memory", score: score.digitSpanScore, color: AppColors.violet)
                    domainBar(label: "Speed", score: score.reactionTimeScore, color: AppColors.coral)
                    domainBar(label: "Visual", score: score.visualMemoryScore, color: AppColors.sky)
                }
            } else {
                Text("Complete a brain assessment to see your domain scores")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
    }

    private func domainBar(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(score))")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text("/ 100")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            GeometryReader { geo in
                Rectangle()
                    .fill(AppColors.cardBorder.opacity(0.34))
                    .frame(height: 2)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(color)
                            .frame(width: geo.size.width * min(1, score / 100), height: 2)
                    }
            }
            .frame(height: 2)
        }
    }

    // MARK: - Focus Mode Stats

    private var focusModeStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FOCUS MODE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppColors.violet)
                    .textCase(.uppercase)

                Spacer()

                if focusModeService.isEnabled {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.violet)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.violet)
                    }
                }
            }

            Divider().opacity(0.3)

            VStack(spacing: 0) {
                statsRow(
                    label: "Shield blocks today",
                    value: "\(focusModeService.dailyAttemptCount)",
                    delta: nil,
                    inverted: false
                )
                thinDivider

                statsRow(
                    label: "Apps blocked",
                    value: "\(focusModeService.blockedAppCount)",
                    delta: nil,
                    inverted: false
                )
                thinDivider

                statsRow(
                    label: "Unlock duration",
                    value: "\(focusModeService.unlockDuration) min",
                    delta: nil,
                    inverted: false
                )

                if focusModeService.isTemporarilyUnlocked, let until = focusModeService.unlockUntil {
                    thinDivider
                    let remaining = max(0, Int(until.timeIntervalSince(.now)) / 60)
                    statsRow(
                        label: "Currently unlocked",
                        value: "\(remaining) min left",
                        delta: nil,
                        inverted: false
                    )
                }
            }

            if !focusModeService.isEnabled {
                Button {
                    showingPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Text("Set up Focus Mode")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.violet)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Pro Sections Teaser (blurred)

    private var proSectionsTeaser: some View {
        ZStack {
            VStack(spacing: 28) {
                personalBestsSection
                trainingHeatmapSection
            }
            .blur(radius: 6)
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)

                Text("Detailed analytics")
                    .font(.system(size: 15, weight: .semibold))

                Text("Personal bests and training activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showingPaywall = true
                } label: {
                    Text("Go Pro")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppColors.accent, in: Capsule())
                }
            }
        }
    }

    // MARK: - 4. Personal Bests (Pro only)

    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERSONAL BESTS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Divider().opacity(0.3)

            let bests = allPersonalBests
            if bests.isEmpty {
                Text("Play some games to see your personal bests")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(bests.enumerated()), id: \.offset) { index, record in
                        statsRow(
                            label: record.type.displayName,
                            value: personalBestDisplay(type: record.type, value: record.best),
                            delta: nil,
                            inverted: false
                        )
                        if index < bests.count - 1 {
                            thinDivider
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. Training Heatmap (Pro only)

    private var trainingHeatmapSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TRAINING ACTIVITY")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            let days = heatmapDays
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

            // Day-of-week headers
            HStack(spacing: 4) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                // Leading spacers for alignment to correct day of week
                ForEach(0..<leadingSpacerCount, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                ForEach(days, id: \.date) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatmapColor(for: day.count))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private struct HeatmapDay {
        let date: Date
        let count: Int
    }

    private var heatmapDays: [HeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build exercise counts per day for last 30 days
        var countsByDay: [Date: Int] = [:]
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today) ?? today

        for exercise in exercises {
            let day = calendar.startOfDay(for: exercise.completedAt)
            if day >= thirtyDaysAgo && day <= today {
                countsByDay[day, default: 0] += 1
            }
        }

        // Generate all 30 days
        return (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: thirtyDaysAgo) else { return nil }
            return HeatmapDay(date: date, count: countsByDay[date] ?? 0)
        }
    }

    /// Number of empty cells before the first day to align with correct weekday column (Mon=0)
    private var leadingSpacerCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let firstDay = calendar.date(byAdding: .day, value: -29, to: today) else { return 0 }
        // weekday: 1=Sun, 2=Mon, ... 7=Sat -> convert to Mon=0
        let weekday = calendar.component(.weekday, from: firstDay)
        // Mon=0, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5, Sun=6
        return (weekday + 5) % 7
    }

    private func heatmapColor(for count: Int) -> Color {
        if count == 0 {
            return AppColors.cardSurface
        } else if count <= 2 {
            return AppColors.accent.opacity(0.3)
        } else {
            return AppColors.accent
        }
    }

    // MARK: - Compact Insight Helpers

    private func glassSelectedCapsule(color: Color) -> some View {
        Capsule()
            .fill(color.opacity(0.16))
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.cardBorder.opacity(0.34),
                                color.opacity(0.08),
                                AppColors.pageBgDark.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.52), lineWidth: 1)
            )
            .overlay(
                Capsule()
                    .stroke(AppColors.cardBorder.opacity(0.28), lineWidth: 0.5)
                    .padding(1)
            )
            .shadow(color: color.opacity(0.10), radius: 8, y: 2)
    }

    private func glassCapsuleStroke(opacity: Double) -> some View {
        Capsule()
            .stroke(AppColors.cardBorder.opacity(opacity), lineWidth: 1)
            .overlay(
                Capsule()
                    .stroke(AppColors.cardBorder.opacity(0.18), lineWidth: 0.5)
                    .padding(1)
            )
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(AppColors.cardBorder.opacity(0.75))
            .frame(width: 1, height: 42)
    }

    private func insightStatColumn(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quietEmptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func deltaLabel(value: Int, inverted: Bool) -> some View {
        let isPositive = value > 0
        // For inverted metrics (brain age), negative = good
        let isGood = inverted ? !isPositive : isPositive
        let color = isGood
            ? AppColors.mint
            : AppColors.coral
        let prefix = isPositive ? "+" : ""
        let suffix = inverted ? "y" : ""

        return Text("\(prefix)\(value)\(suffix)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(color)
    }

    private static let availableGames: [ExerciseType] = [
        .reactionTime, .colorMatch, .speedMatch, .visualMemory,
        .sequentialMemory, .mathSpeed, .dualNBack, .chunkingTraining,
        .chimpTest, .verbalMemory
    ]

    private var bestPersonalRecord: (type: ExerciseType, best: Int)? {
        // Find the game with the highest personal best (normalized by checking all)
        let records: [(type: ExerciseType, best: Int)] = Self.availableGames.compactMap { type in
            let best = PersonalBestTracker.shared.best(for: type)
            guard best > 0 else { return nil }
            return (type: type, best: best)
        }
        // Just return the first non-zero record (most recently set tends to be top)
        return records.first
    }

    /// All personal bests for games the user has played (score > 0)
    private var allPersonalBests: [(type: ExerciseType, best: Int)] {
        Self.availableGames.compactMap { type in
            let best = PersonalBestTracker.shared.best(for: type)
            guard best > 0 else { return nil }
            return (type: type, best: best)
        }
    }

    private func personalBestDisplay(type: ExerciseType, value: Int) -> String {
        switch type {
        case .reactionTime: return "\(1000 - value)ms"
        case .dualNBack: return "N=\(value)"
        case .sequentialMemory: return "\(value) digits"
        case .visualMemory: return "Level \(value)"
        case .mathSpeed: return "\(value) solved"
        case .colorMatch, .speedMatch: return "\(value)%"
        case .chunkingTraining: return "\(value)"
        case .chimpTest: return "Level \(value)"
        case .verbalMemory: return "\(value) words"
        case .wordScramble: return "\(value)/10 words"
        case .memoryChain: return "Chain \(value)"
        default: return "\(value)"
        }
    }

    private func formatTotalTime() -> String {
        let totalSeconds = exercises.reduce(0) { $0 + $1.durationSeconds }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

#if DEBUG
@MainActor
private var progressDashboardPreviewFocusSnapshot: FocusInsightSnapshot {
    FocusInsightSnapshot(
        screenTimeSeconds: TimeInterval(4 * 3600 + 2 * 60),
        pickups: 121,
        weeklyScreenTimeHours: [2.25, 3.83, 3.85, 4.02, 0.72, 2.20, 4.20],
        baselineDailyAverageSeconds: TimeInterval(6 * 3600 + 32 * 60),
        protectedMinutes: 86,
        unlockReps: 9,
        blockedAttempts: 14,
        targetCount: 5,
        passMinutes: 7,
        offenders: [
            FocusInsightOffender(name: "TikTok", durationSeconds: TimeInterval(118 * 60), opens: 29, iconAssetName: "logo-tiktok"),
            FocusInsightOffender(name: "Instagram", durationSeconds: TimeInterval(74 * 60), opens: 21, iconAssetName: "logo-instagram"),
            FocusInsightOffender(name: "YouTube", durationSeconds: TimeInterval(57 * 60), opens: 12, iconAssetName: "logo-youtube"),
            FocusInsightOffender(name: "Reddit", durationSeconds: TimeInterval(34 * 60), opens: 8, iconAssetName: "logo-reddit")
        ],
        isDemoData: true
    )
}

@MainActor
private func makeProgressDashboardPreviewContainer() -> ModelContainer {
    do {
        let container = try ModelContainer(
            for: User.self, Exercise.self, SpacedRepetitionCard.self,
            DailySession.self, BrainScoreResult.self, Achievement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext
        let calendar = Calendar.current

        let user = User()
        user.hasCompletedOnboarding = true
        user.subscriptionStatus = .subscribed
        user.currentStreak = 9
        user.longestStreak = 18
        user.totalExercises = 34
        context.insert(user)

        let scoreSeeds: [(daysAgo: Int, score: Int, age: Int, memory: Double, speed: Double, visual: Double)] = [
            (9, 642, 34, 61, 58, 64),
            (7, 668, 32, 65, 63, 66),
            (5, 681, 31, 69, 66, 70),
            (3, 704, 29, 72, 70, 73),
            (0, 727, 27, 76, 73, 78)
        ]

        for seed in scoreSeeds {
            let result = BrainScoreResult()
            result.date = calendar.date(byAdding: .day, value: -seed.daysAgo, to: Date()) ?? Date()
            result.brainScore = seed.score
            result.brainAge = seed.age
            result.digitSpanScore = seed.memory
            result.reactionTimeScore = seed.speed
            result.visualMemoryScore = seed.visual
            result.digitSpanMax = Int(seed.memory / 10)
            result.reactionTimeAvgMs = max(150, 330 - seed.score / 5)
            result.visualMemoryMax = Int(seed.visual / 10)
            result.percentile = min(99, max(1, seed.score / 10))
            result.source = .workout
            context.insert(result)
        }

        let exerciseSeeds: [(ExerciseType, Int, Double, Int)] = [
            (.reactionTime, 3, 0.91, 42),
            (.visualMemory, 4, 0.84, 65),
            (.sequentialMemory, 4, 0.88, 58),
            (.speedMatch, 3, 0.93, 45),
            (.dualNBack, 4, 0.78, 96),
            (.chimpTest, 3, 0.86, 52)
        ]

        for (index, seed) in exerciseSeeds.enumerated() {
            let exercise = Exercise(type: seed.0, difficulty: seed.1, score: seed.2, durationSeconds: seed.3)
            exercise.completedAt = calendar.date(byAdding: .day, value: -index, to: Date()) ?? Date()
            context.insert(exercise)
        }

        let session = DailySession()
        session.date = Date()
        session.totalScore = 0.87
        session.durationSeconds = 358
        context.insert(session)

        return container
    } catch {
        fatalError("Failed to create Insights preview container: \(error)")
    }
}

struct ProgressDashboardPreviewHost: View {
    @State private var storeService: StoreService
    @State private var focusModeService: FocusModeService

    init() {
        let storeService = StoreService()
        storeService.isProUser = true

        let focusModeService = FocusModeService()
        focusModeService.isEnabled = true
        focusModeService.dailyAttemptCount = 14

        _storeService = State(initialValue: storeService)
        _focusModeService = State(initialValue: focusModeService)
    }

    var body: some View {
        ProgressDashboardView(
            forceDemoFocusReport: true,
            previewFocusSnapshot: progressDashboardPreviewFocusSnapshot
        )
        .environment(storeService)
        .environment(focusModeService)
        .modelContainer(makeProgressDashboardPreviewContainer())
        .preferredColorScheme(.dark)
    }
}

#Preview("Insights - Focus") {
    ProgressDashboardPreviewHost()
}
#endif
