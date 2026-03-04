import SwiftUI

enum CalendarMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

struct NovenasCalendarView: View {
    let environment: AppEnvironment
    @EnvironmentObject private var localization: LocalizationManager
    @State private var mode: CalendarMode = .month
    @State private var showSearch = false
    @State private var showIntentionsSearch = false

    var body: some View {
        LegacyCalendarScaffold(
            headerTitle: "March 2026",
            subtitle: "Novenas • Tap to jump",
            mode: $mode,
            searchTitle: localization.t("calendar.searchNovenas"),
            secondarySearchTitle: localization.t("calendar.searchIntentions"),
            onSearchTap: { showSearch = true },
            onSecondarySearchTap: { showIntentionsSearch = true }
        ) {
            if mode == .month {
                LegacyMonthGrid(sampleText: [
                    "St. Domini...", "·", "St. Franci...", "Release\nfrom A...", "·", "Novena\nfor Fer...", "Feast:\nSts Per..."
                ])
            } else {
                LegacyDayCard(title: "4", subtitle: "Release from Anxiety Novena")
            }
        }
        .sheet(isPresented: $showSearch) {
            NovenasSearchView(environment: environment)
        }
        .sheet(isPresented: $showIntentionsSearch) {
            NovenasSearchView(environment: environment)
        }
    }
}

struct LiturgicalCalendarView: View {
    let environment: AppEnvironment
    @EnvironmentObject private var localization: LocalizationManager
    @State private var mode: CalendarMode = .month
    @State private var showSearch = false

    var body: some View {
        LegacyCalendarScaffold(
            headerTitle: "March 2026",
            subtitle: "Liturgical • Tap to jump",
            mode: $mode,
            searchTitle: localization.t("calendar.search"),
            secondarySearchTitle: nil,
            onSearchTap: { showSearch = true },
            onSecondarySearchTap: nil
        ) {
            if mode == .month {
                LegacyMonthGrid(sampleText: [
                    "Sunday:\nSecond...", "📖", "📖", "📖", "📖", "📖", "📖"
                ])
            } else {
                LegacyDayCard(title: "4", subtitle: "Daily Readings")
            }
        }
        .sheet(isPresented: $showSearch) {
            GlobalSearchView(environment: environment)
        }
    }
}

struct SaintsCalendarView: View {
    let environment: AppEnvironment
    @EnvironmentObject private var localization: LocalizationManager
    @State private var mode: CalendarMode = .day
    @State private var showSearch = false

    var body: some View {
        LegacyCalendarScaffold(
            headerTitle: "March 4, 2026",
            subtitle: "Saints • Tap to jump",
            mode: $mode,
            searchTitle: localization.t("calendar.searchSaints"),
            secondarySearchTitle: nil,
            onSearchTap: { showSearch = true },
            onSecondarySearchTap: nil
        ) {
            if mode == .day {
                LegacyFeaturedSaintCard()
            } else if mode == .week {
                LegacyMonthGrid(sampleText: ["St. Casimir", "St. John", "St. Perpetua", "St. Patrick", "St. Cyril", "St. Joseph", "St. Benedict"])
            } else {
                LegacyMonthGrid(sampleText: [
                    "St. Casimir", "·", "·", "·", "·", "·", "·"
                ])
            }
        }
        .sheet(isPresented: $showSearch) {
            SaintsSearchView(environment: environment)
        }
    }
}

private struct LegacyCalendarScaffold<Content: View>: View {
    @EnvironmentObject private var localization: LocalizationManager
    let headerTitle: String
    let subtitle: String
    @Binding var mode: CalendarMode
    let searchTitle: String
    let secondarySearchTitle: String?
    let onSearchTap: () -> Void
    let onSecondarySearchTap: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text(headerTitle)
                            .font(.system(size: 44, weight: .heavy))
                            .foregroundStyle(.white)
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                    Text(subtitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.subtitleText)
                }

                HStack(spacing: 10) {
                    pillModeButton(localization.t("calendar.today"), isActive: false) {}
                    Spacer(minLength: 8)
                    pillModeButton(localization.t("calendar.day"), isActive: mode == .day) {
                        mode = .day
                    }
                    pillModeButton(localization.t("calendar.week"), isActive: mode == .week) {
                        mode = .week
                    }
                    pillModeButton(localization.t("calendar.month"), isActive: mode == .month) {
                        mode = .month
                    }
                }
                .padding(.horizontal, 14)

                content
                    .padding(.horizontal, 14)

                Spacer(minLength: 8)

                Button(searchTitle, action: onSearchTap)
                    .buttonStyle(PrimaryPillButtonStyle())
                    .padding(.horizontal, 14)

                if let secondarySearchTitle {
                    Button(secondarySearchTitle) { onSecondarySearchTap?() }
                        .buttonStyle(SecondaryPillButtonStyle())
                        .padding(.horizontal, 14)
                }

                HStack(spacing: 16) {
                    seasonDot(color: AppTheme.advent, text: "Advent")
                    seasonDot(color: AppTheme.christmas, text: "Christmas")
                    seasonDot(color: AppTheme.lent, text: "Lent")
                    seasonDot(color: AppTheme.easter, text: "Easter")
                    seasonDot(color: AppTheme.ordinary, text: "Ordinary Time")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .padding(.top, 6)
        }
    }

    private func pillModeButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? Color.white : AppTheme.purpleButton)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(isActive ? AppTheme.purpleButton : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.purpleOutline, lineWidth: isActive ? 0 : 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func seasonDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

private struct LegacyFeaturedSaintCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.13))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.christmas, lineWidth: 4)

            VStack(spacing: 8) {
                Text("4")
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(.white)
                Text("St. Casimir")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                Text("Open details ›")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }
}

private struct LegacyDayCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.13))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.lent, lineWidth: 3)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }
}

private struct LegacyMonthGrid: View {
    let sampleText: [String]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white.opacity(0.82))
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...31, id: \.self) { day in
                    let isSelected = day == 4
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? AppTheme.christmas : AppTheme.lent, lineWidth: isSelected ? 4 : 2)

                        VStack(spacing: 6) {
                            Text("\(day)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                            Text(sampleText[(day - 1) % sampleText.count])
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.86))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding(6)
                    }
                    .frame(height: 86)
                }
            }
        }
    }
}

struct LegacyCalendarViews_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            NovenasCalendarView(environment: .local()).tabItem { Text("Novenas") }
            LiturgicalCalendarView(environment: .local()).tabItem { Text("Liturgical") }
            SaintsCalendarView(environment: .local()).tabItem { Text("Saints") }
        }
    }
}
