import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: AppTab
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var localization: LocalizationManager

    @State private var showLanguageDialog = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack(spacing: 14) {
                            TopActionButton(title: localization.t("home.about"), icon: "info.circle") {
                                showAbout = true
                            }
                            TopActionButton(title: "\(localization.t("home.language")): \(localization.language.displayName)", icon: "translate") {
                                showLanguageDialog = true
                            }
                        }
                        .padding(.top, 14)

                        Image("BrandLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .padding(.top, 8)

                        Text(localization.t("home.welcome"))
                            .font(.system(size: 56, weight: .heavy))
                            .minimumScaleFactor(0.5)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)

                        Text(localization.t("home.connect"))
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppTheme.subtitleText)
                            .padding(.bottom, 4)

                        Button(localization.t("home.saints")) { selectedTab = .saints }
                            .buttonStyle(PrimaryPillButtonStyle())

                        Button(localization.t("tab.novenas")) { selectedTab = .novenas }
                            .buttonStyle(PrimaryPillButtonStyle())

                        Button(localization.t("home.prayers")) {
                            if let url = URL(string: "https://www.fisheaters.com/prayers.html") {
                                openURL(url)
                            }
                        }
                            .buttonStyle(PrimaryPillButtonStyle())

                        Button(localization.t("home.daily")) {
                            if let url = URL(string: "https://bible.usccb.org/daily-bible-reading") {
                                openURL(url)
                            }
                        }
                        .buttonStyle(PrimaryPillButtonStyle())

                        Button(localization.t("home.intentions")) {
                            if let url = URL(string: "https://www.praymorenovenas.com/prayer-intentions") {
                                openURL(url)
                            }
                        }
                            .buttonStyle(PrimaryPillButtonStyle())

                        Button(localization.t("home.parish")) {
                            if let url = URL(string: "https://masstimes.org") {
                                openURL(url)
                            }
                        }
                            .buttonStyle(PrimaryPillButtonStyle())
                            .padding(.bottom, 18)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .sheet(isPresented: $showLanguageDialog) {
                LanguagePickerSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .toolbar(.hidden)
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
                    .font(.system(size: 22, weight: .semibold))
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
                    .font(.system(size: 16, weight: .semibold))
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
        HomeView(selectedTab: .constant(.home))
    }
}
