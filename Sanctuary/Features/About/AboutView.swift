import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        AboutCard(title: localization.t("about.title")) {
                            Text(localization.t("about.subtitle"))
                                .padding(.bottom, 8)
                            Text(localization.t("about.item.liturgical"))
                            Text(localization.t("about.item.saints"))
                            Text(localization.t("about.item.novenas"))
                        }

                        AboutCard(title: localization.t("about.references")) {
                            Text(localization.t("about.refsIntro"))
                            Text(localization.t("about.refsDataSources"))
                                .fontWeight(.bold)
                                .padding(.top, 8)
                            Text(localization.t("about.source.usccb"))
                            Text(localization.t("about.source.fisheaters"))
                            Text(localization.t("about.source.wikipedia"))
                            Text(localization.t("about.source.catholicsaints"))
                            Text(localization.t("about.source.newadvent"))
                            Text(localization.t("about.source.vaticannews"))
                            Text(localization.t("about.source.franciscan"))
                                .padding(.bottom, 8)

                            LinkButton(title: localization.t("about.link.usccb"), url: "https://bible.usccb.org/daily-bible-reading")
                            LinkButton(title: localization.t("about.link.liturgical"), url: "https://mycatholic.life/liturgy/")
                            LinkButton(title: localization.t("about.link.novenas"), url: "https://www.fisheaters.com/novenas.html")
                        }

                        AboutCard(title: localization.t("about.contact")) {
                            Text(localization.t("about.contactBody"))
                            LinkButton(title: localization.t("about.link.reportBug"), url: "mailto:support@sanctuaryapp.com")
                            LinkButton(title: localization.t("about.link.feedback"), url: "mailto:info@sanctuaryapp.com")
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.t("common.close")) { dismiss() }
                        .foregroundStyle(.white)
                }
#else
                ToolbarItem(placement: .navigation) {
                    Button(localization.t("common.close")) { dismiss() }
                        .foregroundStyle(.white)
                }
#endif
            }
        }
    }
}

private struct AboutCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(AppTheme.cardText)

            Divider().background(AppTheme.cardText.opacity(0.25))

            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(AppTheme.cardText.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct LinkButton: View {
    let title: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.purpleButton)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
