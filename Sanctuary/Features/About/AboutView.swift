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
                        Text(localization.t("about.title"))
                            .font(.system(size: 46, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(localization.t("about.subtitle"))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppTheme.subtitleText)

                        AboutCard(title: localization.t("about.whatsInApp")) {
                            Text("• Liturgical: seasons + major celebrations that shape the Church year.")
                            Text("• Saints: saint of the day + other saints commemorated.")
                            Text("• Novenas: novenas that start today + related feast days.")
                        }

                        AboutCard(title: localization.t("about.references")) {
                            Text("Calendar and devotional data are curated from trusted Catholic references and public-domain materials.")
                            Text("Data sources currently used in this app:")
                                .fontWeight(.bold)
                                .padding(.top, 8)
                            Text("• USCCB (daily readings)")
                            Text("• Fish Eaters (novena source content)")
                            Text("• Wikipedia (primary saint enrichment source)")
                            Text("• CatholicSaints.info")
                            Text("• New Advent")
                            Text("• Vatican News")
                            Text("• Franciscan Media")
                                .padding(.bottom, 8)

                            LinkButton(title: "USCCB Daily Bible Reading", url: "https://bible.usccb.org/daily-bible-reading", filled: true)
                            LinkButton(title: "Liturgical calendar reference", url: "https://mycatholic.life/liturgy/", filled: false)
                            LinkButton(title: "Novenas reference", url: "https://www.fisheaters.com/novenas.html", filled: true)
                        }

                        AboutCard(title: localization.t("about.contact")) {
                            Text("To report bugs, request corrections, or send general comments, contact the app team directly.")
                            LinkButton(title: "Report a bug", url: "mailto:support@sanctuaryapp.com", filled: true)
                            LinkButton(title: "Send feedback", url: "mailto:info@sanctuaryapp.com", filled: false)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
#else
                ToolbarItem(placement: .navigation) {
                    Button("Close") { dismiss() }
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
    let filled: Bool

    var body: some View {
        Link(destination: URL(string: url)!) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(filled ? Color.white : AppTheme.purpleButton)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(filled ? AppTheme.purpleButton : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.purpleOutline, lineWidth: filled ? 0 : 2)
                )
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
