import SwiftUI

struct HomeView: View {
    let environment: AppEnvironment
    @EnvironmentObject private var localization: LocalizationManager

    @State private var revealContent = false
    @State private var showLanguageDialog = false
    @State private var showAbout = false
    @State private var showPrayersSearch = false
    @State private var showSaintsSearch = false
    @State private var showNovenasSearch = false
    @State private var showIntentionsSearch = false
    @State private var showParishFinder = false
    @State private var showDailyReadings = false

    private var dailyReadingsURL: URL {
        let today = Date()
        if let localized = localization.language.localizedDailyReadingsURL(
            from: LiturgicalCalendarEngine.readingURL(for: today)?.absoluteString
        ) {
            return localized
        }
        return localization.language.dailyReadingsLandingURL
    }

    private var primaryActions: [HomeAction] {
        [
            HomeAction(title: localization.t("home.saints"), icon: "person.3.fill", tint: AppTheme.glowGold) {
                showSaintsSearch = true
            },
            HomeAction(title: localization.t("tab.novenas"), icon: "book.closed.fill", tint: AppTheme.glowBlue) {
                showNovenasSearch = true
            },
            HomeAction(title: localization.t("home.prayers"), icon: "hands.sparkles.fill", tint: AppTheme.glowRose) {
                showPrayersSearch = true
            },
            HomeAction(title: localization.t("home.daily"), icon: "sun.max.fill", tint: AppTheme.todayHighlight) {
                showDailyReadings = true
            },
            HomeAction(title: localization.t("home.intentions"), icon: "heart.text.square.fill", tint: AppTheme.glowRose) {
                showIntentionsSearch = true
            },
            HomeAction(title: localization.t("home.parish"), icon: "location.fill", tint: AppTheme.glowBlue) {
                showParishFinder = true
            }
        ]
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let width = proxy.size.width
                let scale = ResponsiveLayout.scale(for: width)
                let logoSize = ResponsiveLayout.value(146, width: width)
                let contentWidth = max(0, min(width - 24, 760))

                ZStack {
                    AppBackdrop()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16 * scale) {
                            HStack(spacing: 10 * scale) {
                                TopActionButton(title: localization.t("home.about"), icon: "info.circle") {
                                    showAbout = true
                                }
                                TopActionButton(title: "\(localization.t("home.language")): \(localization.language.displayName)", icon: "translate") {
                                    showLanguageDialog = true
                                }
                            }
                            .padding(.top, 8 * scale)
                            .opacity(revealContent ? 1 : 0)
                            .offset(y: revealContent ? 0 : -8)

                            VStack(spacing: 16 * scale) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.glowGold.opacity(0.22))
                                        .frame(width: logoSize + (44 * scale), height: logoSize + (44 * scale))
                                        .blur(radius: 16)

                                    Image("BrandLogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: logoSize, height: logoSize)
                                        .clipShape(RoundedRectangle(cornerRadius: 30 * scale, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
                                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.26), radius: 22, x: 0, y: 12)
                                }
                                .padding(.top, 6 * scale)

                                VStack(spacing: 10 * scale) {
                                    Text(localization.t("home.welcome"))
                                        .font(AppTheme.rounded(31 * scale, weight: .bold))
                                        .minimumScaleFactor(0.7)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.white)

                                    Text(localization.t("home.connect"))
                                        .font(AppTheme.rounded(17 * scale, weight: .semibold))
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(AppTheme.subtitleText)
                                }

                                Text(localization.t("home.supporting"))
                                    .font(AppTheme.rounded(14 * scale, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.65))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 20 * scale)
                            .padding(.vertical, 18 * scale)
                            .frame(maxWidth: .infinity)
                            .appGlassCard(cornerRadius: 30 * scale)
                            .opacity(revealContent ? 1 : 0)
                            .offset(y: revealContent ? 0 : 14)

                            VStack(spacing: 14 * scale) {
                                ForEach(Array(primaryActions.enumerated()), id: \.offset) { index, action in
                                    Button(action.title, action: action.action)
                                        .buttonStyle(HomePrimaryButtonStyle(icon: action.icon, accent: action.tint))
                                        .opacity(revealContent ? 1 : 0)
                                        .offset(y: revealContent ? 0 : CGFloat(18 + (index * 5)))
                                        .animation(
                                            .spring(response: 0.54, dampingFraction: 0.86)
                                                .delay(0.08 + (Double(index) * 0.04)),
                                            value: revealContent
                                        )
                                }
                            }
                            .padding(.bottom, 18 * scale)
                        }
                        .frame(maxWidth: contentWidth)
                        .padding(.horizontal, 12 * scale)
                        .padding(.top, 6 * scale)
                        .padding(.bottom, 16 * scale)
                    }
                }
            }
            .task {
                guard !revealContent else { return }
                withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) {
                    revealContent = true
                }
            }
            .sheet(isPresented: $showLanguageDialog) {
                LanguagePickerSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showPrayersSearch) {
                PrayersSearchView(environment: environment)
            }
            .sheet(isPresented: $showSaintsSearch) {
                SaintsSearchView(environment: environment)
            }
            .sheet(isPresented: $showNovenasSearch) {
                NovenasSearchView(environment: environment)
            }
            .sheet(isPresented: $showIntentionsSearch) {
                NovenasSearchView(environment: environment, mode: .intentions)
            }
            .sheet(isPresented: $showParishFinder) {
                ParishFinderView()
            }
            .sheet(isPresented: $showDailyReadings) {
                DailyReadingsView(url: dailyReadingsURL)
            }
            .toolbar(.hidden)
        }
    }
}

private struct HomePrimaryButtonStyle: ButtonStyle {
    let icon: String
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.22))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }

            configuration.label
                .font(AppTheme.rounded(18, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
        .shadow(color: Color.black.opacity(configuration.isPressed ? 0.16 : 0.24), radius: 18, x: 0, y: 10)
    }
}

private struct LanguagePickerSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackdrop()
            VStack(alignment: .leading, spacing: 16) {
                Text(localization.t("home.chooseLanguage"))
                    .font(AppTheme.rounded(22, weight: .semibold))
                    .foregroundStyle(AppTheme.cardText)

                ForEach(AppLanguage.allCases) { language in
                    Button(language.displayName) {
                        localization.language = language
                        dismiss()
                    }
                    .buttonStyle(PrimaryPillButtonStyle())
                }

                HStack {
                    Spacer()
                    Button(localization.t("common.close")) {
                        dismiss()
                    }
                    .font(AppTheme.rounded(16, weight: .semibold))
                    .foregroundStyle(AppTheme.purpleOutline)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .appGlassCard()
            .padding(16)
        }
    }
}

private struct HomeAction {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(environment: .local())
    }
}
