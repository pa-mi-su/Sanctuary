import SwiftUI

struct MeView: View {
    let environment: AppEnvironment
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localization.t("tab.me"))
                        .font(.system(size: 52, weight: .heavy))
                        .foregroundStyle(.white)

                    Text(localization.t("me.subtitle"))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.subtitleText)

                    MeCard(title: localization.t("me.inProgress"), subtitle: "4 in progress") {
                        VStack(spacing: 10) {
                            Button("St Gabriel the Archangel Novena") {}
                                .buttonStyle(PrimaryPillButtonStyle())
                            Button("St Albert the Great Novena") {}
                                .buttonStyle(SecondaryPillButtonStyle())
                            Button("Blessed Solanus Casey Novena") {}
                                .buttonStyle(PrimaryPillButtonStyle())
                            Button("30 Day Novena to St Joseph") {}
                                .buttonStyle(SecondaryPillButtonStyle())
                        }
                    }

                    MeCard(title: localization.t("me.favoriteNovenas")) {
                        Text("No favorite novenas yet.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppTheme.cardText.opacity(0.85))
                    }

                    MeCard(title: localization.t("me.favoriteSaints")) {
                        Text("No favorite saints yet.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppTheme.cardText.opacity(0.85))
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct MeCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(AppTheme.cardText)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.cardText.opacity(0.84))
            }
            Divider().background(AppTheme.cardText.opacity(0.25))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView(environment: .local())
    }
}
