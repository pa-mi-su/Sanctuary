import SwiftUI
import SafariServices

enum CalendarMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

private let liturgicalUICalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
    return calendar
}()

private func currentLiturgicalDateComponents() -> DateComponents {
    liturgicalUICalendar.dateComponents([.year, .month, .day], from: Date())
}

struct NovenasCalendarView: View {
    let environment: AppEnvironment
    var openIntentionsToken: Int = 0
    @EnvironmentObject private var localization: LocalizationManager
    @State private var mode: CalendarMode = .month
    @State private var selectedDay = currentLiturgicalDateComponents().day ?? 1
    @State private var selectedMonth = currentLiturgicalDateComponents().month ?? 1
    @State private var selectedYear = currentLiturgicalDateComponents().year ?? 2000
    @State private var showSearch = false
    @State private var showIntentionsSearch = false
    @State private var selectedNovenaSelection: CalendarSelection?
    @State private var tapFeedbackMessage: String?
    @State private var suppressDayTapUntil: Date = .distantPast
    @State private var showDatePicker = false
    @State private var novenaIDByDay: [Int: String] = [:]
    @State private var novenaTitleByDay: [Int: String] = [:]
    @State private var novenaImageURLByDay: [Int: URL] = [:]

    // Reuse central liturgical engine for calendar season coloring.
    private var displayedSeason: LiturgicalSeason {
        LiturgicalLookup.day(forYear: selectedYear, month: selectedMonth, day: selectedDay)?.season
            ?? LiturgicalCalendarEngine.day(for: selectedDate()).season
    }

    private var displayedSeasonBorderColor: Color {
        AppTheme.liturgicalBorderColor(for: displayedSeason)
    }

    private func borderColor(for day: Int) -> Color {
        guard let season = LiturgicalLookup.day(forYear: selectedYear, month: selectedMonth, day: day)?.season else {
            return displayedSeasonBorderColor
        }
        return AppTheme.liturgicalBorderColor(for: season)
    }

    var body: some View {
        let monthName = monthTitle(selectedMonth)
        let maxDay = daysInMonth(year: selectedYear, month: selectedMonth)
        CalendarScaffold(
            headerTitle: mode == .day ? "\(monthName) \(selectedDay), \(selectedYear)" : "\(monthName) \(selectedYear)",
            subtitle: localization.t("calendar.subtitle.novenas"),
            mode: $mode,
            searchTitle: localization.t("calendar.searchNovenas"),
            secondarySearchTitle: localization.t("calendar.searchIntentions"),
            onSearchTap: { showSearch = true },
            onSecondarySearchTap: { showIntentionsSearch = true },
            onPrev: { goPrevious() },
            onNext: { goNext() },
            onToday: {
                let today = currentLiturgicalDateComponents()
                selectedDay = today.day ?? selectedDay
                selectedMonth = today.month ?? selectedMonth
                selectedYear = today.year ?? selectedYear
                mode = .day
            },
            onModeChanged: { suppressDayTapUntil = Date().addingTimeInterval(0.35) },
            onHeaderTap: { showDatePicker = true }
        ) {
            if mode == .month {
                MonthGrid(
                    year: selectedYear,
                    month: selectedMonth,
                    daysInMonth: maxDay,
                    selectedDay: selectedDay,
                    borderColorForDay: borderColor(for:),
                    labelForDay: novenaLabel(for:)
                ) { day in
                    selectedDay = day
                    mode = .day
                }
            } else if mode == .week {
                WeekGrid(
                    year: selectedYear,
                    month: selectedMonth,
                    daysInMonth: maxDay,
                    selectedDay: selectedDay,
                    borderColorForDay: borderColor(for:),
                    labelForDay: novenaLabel(for:)
                ) { day in
                    selectedDay = day
                    mode = .day
                }
            } else {
                DayCard(
                    title: "\(selectedDay)",
                    subtitle: selectedNovenaTitleForDay(),
                    imageURL: selectedNovenaImageURLForDay(),
                    borderColor: displayedSeasonBorderColor,
                    onTap: {
                        guard Date() >= suppressDayTapUntil else { return }
                        let next = novenaIDForSelectedDay()
                        if let next {
                            selectedNovenaSelection = CalendarSelection(id: next)
                        } else {
                            tapFeedbackMessage = "\(localization.t("calendar.noNovenaMapped")) \(monthName) \(selectedDay)."
                        }
                    }
                )
            }
        }
        .task(id: "\(selectedYear)-\(selectedMonth)") {
            await loadNovenaLookups()
        }
        .sheet(isPresented: $showSearch) {
            NovenasSearchView(environment: environment)
        }
        .sheet(isPresented: $showIntentionsSearch) {
            NovenasSearchView(environment: environment, mode: .intentions)
        }
        .onChange(of: openIntentionsToken) { _ in
            showIntentionsSearch = true
        }
        .sheet(item: $selectedNovenaSelection) { selection in
            NovenaDetailView(
                novena: Novena(
                    id: selection.id,
                    slug: selection.id,
                    titleByLocale: [.en: novenaTitleByDay[selectedDay] ?? selection.id],
                    descriptionByLocale: [.en: ""],
                    durationDays: 1,
                    tags: [],
                    imageURL: nil,
                    days: []
                ),
                displayYear: selectedYear,
                onClose: { selectedNovenaSelection = nil }
            )
        }
        .sheet(isPresented: $showDatePicker) {
            CalendarDatePickerSheet(
                initialDate: selectedDate(),
                onApply: { date in apply(date: date) }
            )
        }
        .alert(localization.t("calendar.noEntry"), isPresented: Binding(
            get: { tapFeedbackMessage != nil },
            set: { if !$0 { tapFeedbackMessage = nil } }
        )) {
            Button(localization.t("calendar.ok"), role: .cancel) { tapFeedbackMessage = nil }
        } message: {
            Text(tapFeedbackMessage ?? "")
        }
    }

    private func novenaIDForSelectedDay() -> String? {
        novenaIDByDay[selectedDay]
    }

    private func selectedNovenaTitleForDay() -> String {
        guard let title = novenaTitleByDay[selectedDay] else {
            return localization.t("calendar.noNovenaAvailable")
        }
        return title
    }

    private func novenaLabel(for day: Int) -> String {
        guard let title = novenaTitleByDay[day] else {
            return "·"
        }
        return shortLabel(title)
    }

    private func selectedNovenaImageURLForDay() -> URL? {
        novenaImageURLByDay[selectedDay]
    }

    private func loadNovenaLookups() async {
        let year = selectedYear
        let month = selectedMonth
        let days = daysInMonth(year: selectedYear, month: selectedMonth)
        let loaded = await Task.detached(priority: .userInitiated) {
            var ids: [Int: String] = [:]
            var titles: [Int: String] = [:]
            var images: [Int: URL] = [:]
            for day in 1...days {
                if let id = ContentStore.firstNovenaIDForCalendarDay(onYear: year, month: month, day: day) {
                    ids[day] = id
                }
                if let title = ContentStore.firstNovenaTitleForCalendarDay(onYear: year, month: month, day: day) {
                    titles[day] = title
                }
                if let raw = ContentStore.firstNovenaImageURLStringForCalendarDay(onYear: year, month: month, day: day),
                   let url = urlFromString(raw) {
                    images[day] = url
                }
            }
            return (ids, titles, images)
        }.value

        novenaIDByDay = loaded.0
        novenaTitleByDay = loaded.1
        novenaImageURLByDay = loaded.2
    }

    private func selectedDate() -> Date {
        let clampedDay = min(selectedDay, daysInMonth(year: selectedYear, month: selectedMonth))
        return LiturgicalCalendarEngine.makeDate(year: selectedYear, month: selectedMonth, day: clampedDay)
    }

    private func apply(date: Date) {
        let cal = liturgicalUICalendar
        selectedYear = cal.component(.year, from: date)
        selectedMonth = cal.component(.month, from: date)
        selectedDay = cal.component(.day, from: date)
    }

    private func shift(days: Int) {
        guard let next = liturgicalUICalendar.date(byAdding: .day, value: days, to: selectedDate()) else { return }
        apply(date: next)
    }

    private func shift(months: Int) {
        guard let next = liturgicalUICalendar.date(byAdding: .month, value: months, to: selectedDate()) else { return }
        apply(date: next)
    }

    private func goPrevious() {
        switch mode {
        case .day: shift(days: -1)
        case .week: shift(days: -7)
        case .month: shift(months: -1)
        }
    }

    private func goNext() {
        switch mode {
        case .day: shift(days: 1)
        case .week: shift(days: 7)
        case .month: shift(months: 1)
        }
    }
}

struct LiturgicalCalendarView: View {
    let environment: AppEnvironment
    @EnvironmentObject private var localization: LocalizationManager
    @State private var mode: CalendarMode = .month
    @State private var selectedDay = currentLiturgicalDateComponents().day ?? 1
    @State private var selectedMonth = currentLiturgicalDateComponents().month ?? 1
    @State private var selectedYear = currentLiturgicalDateComponents().year ?? 2000
    @State private var showSearch = false
    @State private var suppressDayTapUntil: Date = .distantPast
    @State private var selectedReadingSelection: ReadingSelection?
    @State private var showDatePicker = false

    // Uses the centralized liturgical engine so season logic is not duplicated in UI.
    private var displayedSeason: LiturgicalSeason {
        LiturgicalLookup.day(forYear: selectedYear, month: selectedMonth, day: selectedDay)?.season
            ?? LiturgicalCalendarEngine.day(for: selectedDate()).season
    }

    private var displayedSeasonBorderColor: Color {
        AppTheme.liturgicalBorderColor(for: displayedSeason)
    }

    private func borderColor(for day: Int) -> Color {
        guard let season = LiturgicalLookup.day(forYear: selectedYear, month: selectedMonth, day: day)?.season else {
            return displayedSeasonBorderColor
        }
        return AppTheme.liturgicalBorderColor(for: season)
    }

    var body: some View {
        let monthName = monthTitle(selectedMonth)
        let maxDay = daysInMonth(year: selectedYear, month: selectedMonth)
        CalendarScaffold(
            headerTitle: mode == .day ? "\(monthName) \(selectedDay), \(selectedYear)" : "\(monthName) \(selectedYear)",
            subtitle: localization.t("calendar.subtitle.liturgical"),
            mode: $mode,
            searchTitle: localization.t("calendar.search"),
            secondarySearchTitle: nil,
            onSearchTap: { showSearch = true },
            onSecondarySearchTap: nil,
            onPrev: { goPrevious() },
            onNext: { goNext() },
            onToday: {
                let today = currentLiturgicalDateComponents()
                selectedDay = today.day ?? selectedDay
                selectedMonth = today.month ?? selectedMonth
                selectedYear = today.year ?? selectedYear
                mode = .day
            },
            onModeChanged: { suppressDayTapUntil = Date().addingTimeInterval(0.35) },
            onHeaderTap: { showDatePicker = true }
        ) {
            if mode == .month {
                MonthGrid(
                    year: selectedYear,
                    month: selectedMonth,
                    daysInMonth: maxDay,
                    selectedDay: selectedDay,
                    borderColorForDay: borderColor(for:),
                    labelForDay: liturgicalLabel(for:)
                ) { day in
                    selectedDay = day
                    mode = .day
                }
            } else if mode == .week {
                WeekGrid(
                    year: selectedYear,
                    month: selectedMonth,
                    daysInMonth: maxDay,
                    selectedDay: selectedDay,
                    borderColorForDay: borderColor(for:),
                    labelForDay: liturgicalLabel(for:)
                ) { day in
                    selectedDay = day
                    mode = .day
                }
            } else {
                DayCard(
                    title: "\(selectedDay)",
                    subtitle: liturgicalTitleForDay(),
                    imageURL: nil,
                    borderColor: displayedSeasonBorderColor,
                    actionLabel: localization.t("calendar.openDailyReadings"),
                    onTap: {
                        guard Date() >= suppressDayTapUntil else { return }
                        let url = liturgicalReadingURLForDay()
                        selectedReadingSelection = ReadingSelection(url: url)
                    }
                )
            }
        }
        .sheet(isPresented: $showSearch) {
            GlobalSearchView(environment: environment)
        }
        .sheet(item: $selectedReadingSelection) { selection in
            DailyReadingsView(url: selection.url)
        }
        .sheet(isPresented: $showDatePicker) {
            CalendarDatePickerSheet(
                initialDate: selectedDate(),
                onApply: { date in apply(date: date) }
            )
        }
    }

    private func liturgicalTitleForDay() -> String {
        LiturgicalLookup.day(forYear: selectedYear, month: selectedMonth, day: selectedDay)?.rank ?? localization.t("calendar.dailyReadings")
    }

    private func liturgicalLabel(for day: Int) -> String {
        if let entry = LiturgicalLookup.day(forYear: selectedYear, month: selectedMonth, day: day) {
            return shortLabel(entry.rank)
        }
        return "📖"
    }

    private func liturgicalReadingURLForDay() -> URL {
        if let raw = LiturgicalLookup.day(forYear: selectedYear, month: selectedMonth, day: selectedDay)?.readingURL,
           let url = urlFromString(raw) {
            return url
        }
        return URL(string: "https://bible.usccb.org/daily-bible-reading")!
    }

    private func selectedDate() -> Date {
        let clampedDay = min(selectedDay, daysInMonth(year: selectedYear, month: selectedMonth))
        return LiturgicalCalendarEngine.makeDate(year: selectedYear, month: selectedMonth, day: clampedDay)
    }

    private func apply(date: Date) {
        let cal = liturgicalUICalendar
        selectedYear = cal.component(.year, from: date)
        selectedMonth = cal.component(.month, from: date)
        selectedDay = cal.component(.day, from: date)
    }

    private func shift(days: Int) {
        guard let next = liturgicalUICalendar.date(byAdding: .day, value: days, to: selectedDate()) else { return }
        apply(date: next)
    }

    private func shift(months: Int) {
        guard let next = liturgicalUICalendar.date(byAdding: .month, value: months, to: selectedDate()) else { return }
        apply(date: next)
    }

    private func goPrevious() {
        switch mode {
        case .day: shift(days: -1)
        case .week: shift(days: -7)
        case .month: shift(months: -1)
        }
    }

    private func goNext() {
        switch mode {
        case .day: shift(days: 1)
        case .week: shift(days: 7)
        case .month: shift(months: 1)
        }
    }
}

struct SaintsCalendarView: View {
    let environment: AppEnvironment
    @EnvironmentObject private var localization: LocalizationManager
    @State private var mode: CalendarMode = .day
    @State private var selectedDay = currentLiturgicalDateComponents().day ?? 1
    @State private var selectedMonth = currentLiturgicalDateComponents().month ?? 1
    @State private var selectedYear = currentLiturgicalDateComponents().year ?? 2000
    @State private var showSearch = false
    @State private var selectedSaintSelection: CalendarSelection?
    @State private var tapFeedbackMessage: String?
    @State private var suppressDayTapUntil: Date = .distantPast
    @State private var saintIDByDay: [Int: String] = [:]
    @State private var saintNameByDay: [Int: String] = [:]
    @State private var saintImageURLByDay: [Int: URL] = [:]
    @State private var showDatePicker = false

    // Reuse central liturgical engine for calendar season coloring.
    private var displayedSeason: LiturgicalSeason {
        LiturgicalLookup.day(forYear: selectedYear, month: selectedMonth, day: selectedDay)?.season
            ?? LiturgicalCalendarEngine.day(for: selectedDate()).season
    }

    private var displayedSeasonBorderColor: Color {
        AppTheme.liturgicalBorderColor(for: displayedSeason)
    }

    private func borderColor(for day: Int) -> Color {
        guard let season = LiturgicalLookup.day(forYear: selectedYear, month: selectedMonth, day: day)?.season else {
            return displayedSeasonBorderColor
        }
        return AppTheme.liturgicalBorderColor(for: season)
    }

    var body: some View {
        let monthName = monthTitle(selectedMonth)
        let maxDay = daysInMonth(year: selectedYear, month: selectedMonth)
        CalendarScaffold(
            headerTitle: mode == .day ? "\(monthName) \(selectedDay), \(selectedYear)" : "\(monthName) \(selectedYear)",
            subtitle: localization.t("calendar.subtitle.saints"),
            mode: $mode,
            searchTitle: localization.t("calendar.searchSaints"),
            secondarySearchTitle: nil,
            onSearchTap: { showSearch = true },
            onSecondarySearchTap: nil,
            onPrev: { goPrevious() },
            onNext: { goNext() },
            onToday: {
                let today = currentLiturgicalDateComponents()
                selectedDay = today.day ?? selectedDay
                selectedMonth = today.month ?? selectedMonth
                selectedYear = today.year ?? selectedYear
                mode = .day
            },
            onModeChanged: { suppressDayTapUntil = Date().addingTimeInterval(0.35) },
            onHeaderTap: { showDatePicker = true }
        ) {
            if mode == .day {
                DayCard(
                    title: "\(selectedDay)",
                    subtitle: selectedSaintNameForDay(),
                    imageURL: selectedSaintImageURLForDay(),
                    borderColor: displayedSeasonBorderColor,
                    onTap: {
                        guard Date() >= suppressDayTapUntil else { return }
                        let next = saintIDForSelectedDay()
                        if let next {
                            selectedSaintSelection = CalendarSelection(id: next)
                        } else {
                            tapFeedbackMessage = "\(localization.t("calendar.noSaintMapped")) \(monthName) \(selectedDay)."
                        }
                    }
                )
            } else if mode == .week {
                WeekGrid(
                    year: selectedYear,
                    month: selectedMonth,
                    daysInMonth: maxDay,
                    selectedDay: selectedDay,
                    borderColorForDay: borderColor(for:),
                    labelForDay: saintLabel(for:)
                ) { day in
                    selectedDay = day
                    mode = .day
                }
            } else {
                MonthGrid(
                    year: selectedYear,
                    month: selectedMonth,
                    daysInMonth: maxDay,
                    selectedDay: selectedDay,
                    borderColorForDay: borderColor(for:),
                    labelForDay: saintLabel(for:)
                ) { day in
                    selectedDay = day
                    mode = .day
                }
            }
        }
        .task(id: "\(selectedYear)-\(selectedMonth)") {
            await loadSaintLookups()
        }
        .sheet(isPresented: $showSearch) {
            SaintsSearchView(environment: environment)
        }
        .sheet(item: $selectedSaintSelection) { selection in
            SaintDetailView(
                saint: Saint(
                    id: selection.id,
                    slug: selection.id,
                    name: saintNameByDay[selectedDay] ?? localization.t("tab.saints"),
                    feastMonth: selectedMonth,
                    feastDay: selectedDay,
                    imageURL: nil,
                    tags: [],
                    patronages: [],
                    feastLabelByLocale: [.en: ""],
                    summaryByLocale: [.en: ""],
                    biographyByLocale: [.en: ""],
                    prayersByLocale: [.en: []],
                    sources: []
                ),
                displayYear: selectedYear,
                onClose: { selectedSaintSelection = nil }
            )
        }
        .alert(localization.t("calendar.noEntry"), isPresented: Binding(
            get: { tapFeedbackMessage != nil },
            set: { if !$0 { tapFeedbackMessage = nil } }
        )) {
            Button(localization.t("calendar.ok"), role: .cancel) { tapFeedbackMessage = nil }
        } message: {
            Text(tapFeedbackMessage ?? "")
        }
        .sheet(isPresented: $showDatePicker) {
            CalendarDatePickerSheet(
                initialDate: selectedDate(),
                onApply: { date in apply(date: date) }
            )
        }
    }

    private func saintIDForSelectedDay() -> String? {
        saintIDByDay[selectedDay]
    }

    private func selectedSaintNameForDay() -> String {
        saintNameByDay[selectedDay] ?? localization.t("tab.saints")
    }

    private func saintLabel(for day: Int) -> String {
        guard let name = saintNameByDay[day] else {
            return "·"
        }
        return shortLabel(name)
    }

    private func selectedSaintImageURLForDay() -> URL? {
        saintImageURLByDay[selectedDay]
    }

    private func loadSaintLookups() async {
        let month = selectedMonth
        let days = daysInMonth(year: selectedYear, month: selectedMonth)
        let loaded = await Task.detached(priority: .userInitiated) {
            var ids: [Int: String] = [:]
            var names: [Int: String] = [:]
            var images: [Int: URL] = [:]
            for day in 1...days {
                if let id = ContentStore.firstSaintID(onMonth: month, day: day) {
                    ids[day] = id
                }
                if let name = ContentStore.firstSaintName(onMonth: month, day: day) {
                    names[day] = name
                }
                if let raw = ContentStore.firstSaintPhotoURLString(onMonth: month, day: day),
                   let url = urlFromString(raw) {
                    images[day] = url
                }
            }
            return (ids, names, images)
        }.value

        saintIDByDay = loaded.0
        saintNameByDay = loaded.1
        saintImageURLByDay = loaded.2
    }

    private func selectedDate() -> Date {
        let clampedDay = min(selectedDay, daysInMonth(year: selectedYear, month: selectedMonth))
        return LiturgicalCalendarEngine.makeDate(year: selectedYear, month: selectedMonth, day: clampedDay)
    }

    private func apply(date: Date) {
        let cal = liturgicalUICalendar
        selectedYear = cal.component(.year, from: date)
        selectedMonth = cal.component(.month, from: date)
        selectedDay = cal.component(.day, from: date)
    }

    private func shift(days: Int) {
        guard let next = liturgicalUICalendar.date(byAdding: .day, value: days, to: selectedDate()) else { return }
        apply(date: next)
    }

    private func shift(months: Int) {
        guard let next = liturgicalUICalendar.date(byAdding: .month, value: months, to: selectedDate()) else { return }
        apply(date: next)
    }

    private func goPrevious() {
        switch mode {
        case .day: shift(days: -1)
        case .week: shift(days: -7)
        case .month: shift(months: -1)
        }
    }

    private func goNext() {
        switch mode {
        case .day: shift(days: 1)
        case .week: shift(days: 7)
        case .month: shift(months: 1)
        }
    }
}

private struct CalendarScaffold<Content: View>: View {
    @EnvironmentObject private var localization: LocalizationManager
    let headerTitle: String
    let subtitle: String
    @Binding var mode: CalendarMode
    let searchTitle: String
    let secondarySearchTitle: String?
    let onSearchTap: () -> Void
    let onSecondarySearchTap: (() -> Void)?
    let onPrev: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    let onModeChanged: () -> Void
    let onHeaderTap: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let scale = ResponsiveLayout.scale(for: width)
            let contentWidth = max(0, min(width - 24, 760))

            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 10 * scale) {
                    VStack(spacing: 4 * scale) {
                        HStack {
                            Button(action: onPrev) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24 * scale, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Button {
                                onHeaderTap?()
                            } label: {
                                HStack(spacing: 6) {
                                    Text(headerTitle)
                                        .font(AppTheme.rounded(27 * scale, weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                    if onHeaderTap != nil {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 16 * scale, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(action: onNext) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 24 * scale, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 12 * scale)
                        .padding(.top, 6 * scale)

                        Text(subtitle)
                            .font(AppTheme.rounded(14 * scale, weight: .medium))
                            .foregroundStyle(AppTheme.subtitleText)
                    }

                    HStack(spacing: 8 * scale) {
                        pillModeButton(localization.t("calendar.today"), isActive: false, action: onToday)
                        Spacer(minLength: 6 * scale)
                        pillModeButton(localization.t("calendar.day"), isActive: mode == .day) {
                            onModeChanged()
                            mode = .day
                        }
                        pillModeButton(localization.t("calendar.week"), isActive: mode == .week) {
                            onModeChanged()
                            mode = .week
                        }
                        pillModeButton(localization.t("calendar.month"), isActive: mode == .month) {
                            onModeChanged()
                            mode = .month
                        }
                    }
                    .padding(.horizontal, 12 * scale)

                    content
                        .padding(.horizontal, 12 * scale)

                    Spacer(minLength: 6 * scale)

                    Button(searchTitle, action: onSearchTap)
                        .buttonStyle(PrimaryPillButtonStyle())
                        .padding(.horizontal, 12 * scale)

                    if let secondarySearchTitle {
                        Button(secondarySearchTitle) { onSecondarySearchTap?() }
                            .buttonStyle(SecondaryPillButtonStyle())
                            .padding(.horizontal, 12 * scale)
                    }

                    HStack(spacing: 12 * scale) {
                        seasonDot(color: AppTheme.advent, text: localization.t("season.advent"))
                        seasonDot(color: AppTheme.christmas, text: localization.t("season.christmas"))
                        seasonDot(color: AppTheme.lent, text: localization.t("season.lent"))
                        seasonDot(color: AppTheme.easter, text: localization.t("season.easter"))
                        seasonDot(color: AppTheme.ordinary, text: localization.t("season.ordinary"))
                    }
                    .font(AppTheme.rounded(11 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.top, 2 * scale)
                    .padding(.bottom, 8 * scale)
                }
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 4 * scale)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            if value.translation.width < -40 {
                                onNext()
                            } else if value.translation.width > 40 {
                                onPrev()
                            }
                        }
                )
            }
        }
    }

    private func pillModeButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.rounded(17, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : AppTheme.purpleButton)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(isActive ? AppTheme.purpleButton : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.purpleOutline, lineWidth: isActive ? 0 : 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

private struct DayCard: View {
    @EnvironmentObject private var localization: LocalizationManager
    let title: String
    let subtitle: String
    let imageURL: URL?
    var borderColor: Color = AppTheme.lent
    var actionLabel: String? = nil
    let onTap: () -> Void
    private let cardHeight: CGFloat = 142

    var body: some View {
        let outerShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let innerShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button(action: onTap) {
            ZStack {
                outerShape
                    .fill(Color.white.opacity(0.13))

                if let imageURL {
                    GeometryReader { geo in
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                ZStack {
                                    // Backdrop fills the card and is intentionally blurred.
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .blur(radius: 24)
                                        .saturation(0.65)
                                        .opacity(0.8)

                                    // Foreground always shows the full image (no crop/zoom).
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(
                                            width: max(0, geo.size.width - 18),
                                            height: max(0, geo.size.height - 18)
                                        )
                                        .clipShape(innerShape)
                                        .overlay(
                                            innerShape
                                                .stroke(Color.white.opacity(0.38), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 2)
                                }
                            case .empty:
                                Color.white.opacity(0.08)
                            case .failure:
                                Color.white.opacity(0.08)
                            @unknown default:
                                Color.white.opacity(0.08)
                            }
                        }
                    }
                    .clipShape(outerShape)

                }

                outerShape
                    .strokeBorder(borderColor, lineWidth: 3)

                outerShape
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)

                VStack(spacing: 8) {
                    Text(title)
                        .font(AppTheme.rounded(33, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(AppTheme.rounded(16, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text("\(actionLabel ?? localization.t("calendar.openDetails")) ›")
                        .font(AppTheme.rounded(13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .clipShape(outerShape)
        }
        .contentShape(outerShape)
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .buttonStyle(.plain)
    }
}

private struct MonthGrid: View {
    @EnvironmentObject private var localization: LocalizationManager
    let year: Int
    let month: Int
    let daysInMonth: Int
    let selectedDay: Int
    var borderColorForDay: (Int) -> Color = { _ in AppTheme.lent }
    let labelForDay: (Int) -> String
    let onDayTap: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    private var leadingEmptyCells: Int { firstWeekdayOffset(year: year, month: month) }
    private var todayComponents: DateComponents {
        currentLiturgicalDateComponents()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            weekHeaderRow

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0 ..< leadingEmptyCells, id: \.self) { _ in
                    Color.clear.frame(height: 72)
                }
                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day: day, label: labelForDay(day))
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Int, label: String) -> some View {
        let isToday = todayComponents.year == year && todayComponents.month == month && todayComponents.day == day
        Button {
            onDayTap(day)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isToday ? AppTheme.todayHighlight : borderColorForDay(day), lineWidth: isToday ? 4 : 2)

                VStack(spacing: 6) {
                    Text("\(day)")
                        .font(AppTheme.rounded(15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(label)
                        .font(AppTheme.rounded(10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(6)
            }
        }
        .frame(height: 72)
        .buttonStyle(.plain)
    }

    private var weekHeaderRow: some View {
        HStack {
            ForEach(localization.weekdaySymbolsShort(), id: \.self) { day in
                Text(day)
                    .font(AppTheme.rounded(13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
    }
}

private struct WeekGrid: View {
    @EnvironmentObject private var localization: LocalizationManager
    let year: Int
    let month: Int
    let daysInMonth: Int
    let selectedDay: Int
    var borderColorForDay: (Int) -> Color = { _ in AppTheme.lent }
    let labelForDay: (Int) -> String
    let onDayTap: (Int) -> Void

    private var weekStartDay: Int {
        let weekday = weekdayForDate(year: year, month: month, day: selectedDay)
        return selectedDay - (weekday - 1)
    }
    private var todayComponents: DateComponents {
        currentLiturgicalDateComponents()
    }
    private var weekDays: [Int?] {
        (0...6).map { offset in
            let value = weekStartDay + offset
            return (1...daysInMonth).contains(value) ? value : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(localization.weekdaySymbolsShort(), id: \.self) { day in
                    Text(day)
                        .font(AppTheme.rounded(13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white.opacity(0.82))
                }
            }

            HStack(spacing: 10) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, maybeDay in
                    if let day = maybeDay {
                        let isToday = todayComponents.year == year && todayComponents.month == month && todayComponents.day == day
                        Button {
                            onDayTap(day)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.14))
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isToday ? AppTheme.todayHighlight : borderColorForDay(day), lineWidth: isToday ? 4 : 2)

                                VStack(spacing: 6) {
                                    Text("\(day)")
                                        .font(AppTheme.rounded(15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(labelForDay(day))
                                        .font(AppTheme.rounded(10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.86))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .padding(6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                    }
                }
            }
        }
    }
}

private func firstWeekdayOffset(year: Int, month: Int) -> Int {
    let weekday = weekdayForDate(year: year, month: month, day: 1)
    return max(0, weekday - 1)
}

private func weekdayForDate(year: Int, month: Int, day: Int) -> Int {
    let components = DateComponents(year: year, month: month, day: day, hour: 12)
    guard let date = liturgicalUICalendar.date(from: components) else { return 1 }
    return liturgicalUICalendar.component(.weekday, from: date)
}

private func mapSourceSaint(_ doc: SaintDocument) -> Saint {
    let mmdd = doc.mmdd ?? "01-01"
    let parts = mmdd.split(separator: "-")
    let month = parts.count == 2 ? Int(parts[0]) ?? 1 : 1
    let day = parts.count == 2 ? Int(parts[1]) ?? 1 : 1

    return Saint(
        id: doc.id,
        slug: doc.id,
        name: doc.name ?? doc.id,
        feastMonth: month,
        feastDay: day,
        imageURL: urlFromString(doc.photoUrl),
        tags: [],
        patronages: [],
        feastLabelByLocale: [
            .en: doc.feast ?? "",
            .es: doc.feast_es ?? doc.feast ?? "",
            .pl: doc.feast_pl ?? doc.feast ?? "",
        ],
        summaryByLocale: [
            .en: doc.summary ?? "",
            .es: doc.summary_es ?? doc.summary ?? "",
            .pl: doc.summary_pl ?? doc.summary ?? "",
        ],
        biographyByLocale: [
            .en: doc.biography ?? "",
            .es: doc.biography_es ?? doc.biography ?? "",
            .pl: doc.biography_pl ?? doc.biography ?? "",
        ],
        prayersByLocale: [.en: doc.prayers ?? [], .es: doc.prayers ?? [], .pl: doc.prayers ?? []],
        sources: doc.sources ?? []
    )
}

private func mapSourceNovena(_ doc: NovenaDocument) -> Novena {
    let titleByLocale: [ContentLocale: String] = [
        .en: doc.title ?? doc.id,
        .es: doc.title_es ?? doc.title ?? doc.id,
        .pl: doc.title_pl ?? doc.title ?? doc.id,
    ]
    let descriptionByLocale: [ContentLocale: String] = [
        .en: doc.description ?? "",
        .es: doc.description_es ?? doc.description ?? "",
        .pl: doc.description_pl ?? doc.description ?? "",
    ]

    let days = (doc.days ?? []).map { d in
        let title: [ContentLocale: String] = [
            .en: d.title ?? "",
            .es: d.title_es ?? d.title ?? "",
            .pl: d.title_pl ?? d.title ?? "",
        ]
        let scripture: [ContentLocale: String] = [
            .en: d.scripture ?? "",
            .es: d.scripture_es ?? d.scripture ?? "",
            .pl: d.scripture_pl ?? d.scripture ?? "",
        ]
        let prayer: [ContentLocale: String] = [
            .en: d.prayer ?? "",
            .es: d.prayer_es ?? d.prayer ?? "",
            .pl: d.prayer_pl ?? d.prayer ?? "",
        ]
        let reflection: [ContentLocale: String] = [
            .en: d.reflection ?? "",
            .es: d.reflection_es ?? d.reflection ?? "",
            .pl: d.reflection_pl ?? d.reflection ?? "",
        ]

        return NovenaDay(
            dayNumber: d.day ?? 1,
            titleByLocale: title,
            scriptureByLocale: scripture,
            prayerByLocale: prayer,
            reflectionByLocale: reflection,
            bodyByLocale: [
                .en: [title[.en], scripture[.en], prayer[.en], reflection[.en]].compactMap { $0 }.joined(separator: "\n\n"),
                .es: [title[.es], scripture[.es], prayer[.es], reflection[.es]].compactMap { $0 }.joined(separator: "\n\n"),
                .pl: [title[.pl], scripture[.pl], prayer[.pl], reflection[.pl]].compactMap { $0 }.joined(separator: "\n\n"),
            ]
        )
    }

    return Novena(
        id: doc.id,
        slug: doc.id,
        titleByLocale: titleByLocale,
        descriptionByLocale: descriptionByLocale,
        durationDays: doc.durationDays ?? max(1, days.count),
        tags: doc.tags ?? [],
        imageURL: urlFromString(doc.image),
        days: days
    )
}

private func urlFromString(_ raw: String?) -> URL? {
    guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    if let direct = URL(string: raw) { return direct }
    return raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init(string:))
}

private struct CalendarSelection: Identifiable {
    let id: String
}

private func shortLabel(_ raw: String, max: Int = 14) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > max else { return trimmed }
    return String(trimmed.prefix(max - 1)) + "…"
}

private func monthTitle(_ month: Int) -> String {
    let formatter = DateFormatter()
    return formatter.monthSymbols[max(0, min(11, month - 1))]
}

private func daysInMonth(year: Int, month: Int) -> Int {
    var components = DateComponents()
    components.year = year
    components.month = month
    guard let date = liturgicalUICalendar.date(from: components),
          let range = liturgicalUICalendar.range(of: .day, in: .month, for: date)
    else {
        return 31
    }
    return range.count
}

private enum LiturgicalLookup {
    struct Entry: Hashable {
        let date: String
        let rank: String
        let readingURL: String?
        let season: LiturgicalSeason
    }

    static func day(forYear year: Int, month: Int, day: Int) -> Entry? {
        let date = LiturgicalCalendarEngine.makeDate(year: year, month: month, day: day)
        let liturgicalDay = LiturgicalCalendarEngine.day(for: date)
        return Entry(
            date: String(format: "%04d-%02d-%02d", year, month, day),
            rank: liturgicalDay.rank,
            readingURL: liturgicalDay.readingURL?.absoluteString,
            season: liturgicalDay.season
        )
    }
}

private struct ReadingSelection: Identifiable {
    let id = UUID()
    let url: URL
}

private struct CalendarDatePickerSheet: View {
    @EnvironmentObject private var localization: LocalizationManager
    let initialDate: Date
    let onApply: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(initialDate: Date, onApply: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onApply = onApply
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    localization.t("common.pickDateLabel"),
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .padding(.horizontal, 12)
                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle(localization.t("calendar.pickDate"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.t("common.apply")) {
                        onApply(selectedDate)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct DailyReadingsView: View {
    @EnvironmentObject private var localization: LocalizationManager
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            InAppSafariView(url: url)
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(localization.t("common.close")) { dismiss() }
                    }
                }
        }
    }
}

struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct CalendarViews_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            NovenasCalendarView(environment: .local()).tabItem { Text("Novenas") }
            LiturgicalCalendarView(environment: .local()).tabItem { Text("Liturgical") }
            SaintsCalendarView(environment: .local()).tabItem { Text("Saints") }
        }
    }
}
