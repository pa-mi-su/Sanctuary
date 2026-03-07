import SwiftUI

struct HomeView: View {
    let environment: AppEnvironment
    @Binding var selectedTab: AppTab
    let onOpenIntentions: () -> Void
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var localization: LocalizationManager

    @State private var showLanguageDialog = false
    @State private var showAbout = false
    @State private var showPrayersSearch = false
    @State private var showParishFinder = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let width = proxy.size.width
                let scale = ResponsiveLayout.scale(for: width)
                let logoSize = ResponsiveLayout.value(150, width: width)
                let contentWidth = max(0, min(width - 24, 760))

                ZStack {
                    AppTheme.backgroundGradient.ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12 * scale) {
                            HStack(spacing: 10 * scale) {
                                TopActionButton(title: localization.t("home.about"), icon: "info.circle") {
                                    showAbout = true
                                }
                                TopActionButton(title: "\(localization.t("home.language")): \(localization.language.displayName)", icon: "translate") {
                                    showLanguageDialog = true
                                }
                            }
                            .padding(.top, 10 * scale)

                            Image("BrandLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: logoSize, height: logoSize)
                                .clipShape(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
                                .padding(.top, 4 * scale)

                            Text(localization.t("home.welcome"))
                                .font(AppTheme.rounded(31 * scale, weight: .bold))
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)

                            Text(localization.t("home.connect"))
                                .font(AppTheme.rounded(17 * scale, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(AppTheme.subtitleText)
                                .padding(.bottom, 2 * scale)

                            Button(localization.t("home.saints")) { switchTab(.saints) }
                                .buttonStyle(HomePrimaryButtonStyle())

                            Button(localization.t("tab.novenas")) { switchTab(.novenas) }
                                .buttonStyle(HomePrimaryButtonStyle())

                            Button(localization.t("home.prayers")) {
                                showPrayersSearch = true
                            }
                            .buttonStyle(HomePrimaryButtonStyle())

                            Button(localization.t("home.daily")) {
                                if let url = URL(string: "https://bible.usccb.org/daily-bible-reading") {
                                    openURL(url)
                                }
                            }
                            .buttonStyle(HomePrimaryButtonStyle())

                            Button(localization.t("home.intentions")) {
                                switchTab(.novenas)
                                onOpenIntentions()
                            }
                            .buttonStyle(HomePrimaryButtonStyle())

                            Button(localization.t("home.parish")) {
                                showParishFinder = true
                            }
                            .buttonStyle(HomePrimaryButtonStyle())
                            .padding(.bottom, 18 * scale)
                        }
                        .frame(maxWidth: contentWidth)
                        .padding(.horizontal, 12 * scale)
                        .padding(.bottom, 16 * scale)
                    }
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
            .sheet(isPresented: $showParishFinder) {
                ParishFinderView()
            }
            .toolbar(.hidden)
        }
    }
}

private struct HomePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.rounded(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.purpleButton.opacity(configuration.isPressed ? 0.82 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension HomeView {
    func switchTab(_ tab: AppTab) {
        // Keep tap path pure: state change only, no IO or background kickoff.
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            selectedTab = tab
        }
    }
}

private struct LanguagePickerSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.cardBackground.ignoresSafeArea()
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
                    .foregroundStyle(AppTheme.purpleButton)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(environment: .local(), selectedTab: .constant(.home), onOpenIntentions: {})
    }
}
