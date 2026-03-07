import Foundation

@inline(__always)
func assertOrExit(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    let cal = Calendar(identifier: .gregorian)
    return cal.date(from: DateComponents(year: y, month: m, day: d))!
}

func yyyyMMdd(_ date: Date) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

@main
struct NovenaRuleTestMain {
    static func main() {
        let root = FileManager.default.currentDirectoryPath
        setenv("SANCTUARY_RESOURCE_ROOT", root, 1)

        // Divine Mercy 2026: Good Friday 2026-04-03 to Saturday before Divine Mercy Sunday 2026-04-11
        if let w = ContentStore.novenaServingWindow(id: "divine_mercy", year: 2026) {
            assertOrExit(yyyyMMdd(w.start) == "2026-04-03", "divine_mercy 2026 start expected 2026-04-03, got \(yyyyMMdd(w.start))")
            assertOrExit(yyyyMMdd(w.end) == "2026-04-11", "divine_mercy 2026 end expected 2026-04-11, got \(yyyyMMdd(w.end))")
            assertOrExit(yyyyMMdd(w.feast) == "2026-04-12", "divine_mercy 2026 feast expected 2026-04-12, got \(yyyyMMdd(w.feast))")
        } else {
            assertOrExit(false, "divine_mercy 2026 window missing")
        }

        // Divine Mercy 2030
        if let w = ContentStore.novenaServingWindow(id: "divine_mercy", year: 2030) {
            assertOrExit(yyyyMMdd(w.start) == "2030-04-19", "divine_mercy 2030 start expected 2030-04-19, got \(yyyyMMdd(w.start))")
            assertOrExit(yyyyMMdd(w.end) == "2030-04-27", "divine_mercy 2030 end expected 2030-04-27, got \(yyyyMMdd(w.end))")
            assertOrExit(yyyyMMdd(w.feast) == "2030-04-28", "divine_mercy 2030 feast expected 2030-04-28, got \(yyyyMMdd(w.feast))")
        } else {
            assertOrExit(false, "divine_mercy 2030 window missing")
        }

        // Status transitions for Divine Mercy 2026.
        assertOrExit(ContentStore.novenaServingStatus(id: "divine_mercy", on: date(2026, 4, 2)) == .notYetStarted, "divine_mercy 2026-04-02 should be notYetStarted")
        assertOrExit(ContentStore.novenaServingStatus(id: "divine_mercy", on: date(2026, 4, 3)) == .active, "divine_mercy 2026-04-03 should be active")
        assertOrExit(ContentStore.novenaServingStatus(id: "divine_mercy", on: date(2026, 4, 11)) == .active, "divine_mercy 2026-04-11 should be active")
        assertOrExit(ContentStore.novenaServingStatus(id: "divine_mercy", on: date(2026, 4, 12)) == .completed, "divine_mercy 2026-04-12 should be completed")

        // Calendar listing is start-day only (not full active span).
        assertOrExit(
            ContentStore.firstNovenaIDForCalendarDay(onYear: 2026, month: 4, day: 3) == "divine_mercy",
            "calendar should list divine_mercy on start day 2026-04-03"
        )
        assertOrExit(
            ContentStore.firstNovenaIDForCalendarDay(onYear: 2026, month: 4, day: 4) != "divine_mercy",
            "calendar should not list divine_mercy on non-start day 2026-04-04"
        )

        // Movable example 1: Novena to the Holy Spirit (2026)
        if let w = ContentStore.novenaServingWindow(id: "novena_to_the_holy_spirit", year: 2026) {
            assertOrExit(yyyyMMdd(w.start) == "2026-05-15", "holy_spirit 2026 start expected 2026-05-15, got \(yyyyMMdd(w.start))")
            assertOrExit(yyyyMMdd(w.end) == "2026-05-23", "holy_spirit 2026 end expected 2026-05-23, got \(yyyyMMdd(w.end))")
            assertOrExit(yyyyMMdd(w.feast) == "2026-05-24", "holy_spirit 2026 feast expected 2026-05-24, got \(yyyyMMdd(w.feast))")
        } else {
            assertOrExit(false, "novena_to_the_holy_spirit 2026 window missing")
        }

        // Movable example 2: Sacred Heart (2030)
        if let w = ContentStore.novenaServingWindow(id: "sacred_heart", year: 2030) {
            assertOrExit(yyyyMMdd(w.start) == "2030-06-19", "sacred_heart 2030 start expected 2030-06-19, got \(yyyyMMdd(w.start))")
            assertOrExit(yyyyMMdd(w.end) == "2030-06-27", "sacred_heart 2030 end expected 2030-06-27, got \(yyyyMMdd(w.end))")
            assertOrExit(yyyyMMdd(w.feast) == "2030-06-28", "sacred_heart 2030 feast expected 2030-06-28, got \(yyyyMMdd(w.feast))")
        } else {
            assertOrExit(false, "sacred_heart 2030 window missing")
        }

        // Fixed-window example: St. Andrew Christmas Novena (Nov 30 through Dec 24)
        if let w = ContentStore.novenaServingWindow(id: "st_andrew_christmas", year: 2026) {
            assertOrExit(yyyyMMdd(w.start) == "2026-11-30", "st_andrew_christmas 2026 start expected 2026-11-30, got \(yyyyMMdd(w.start))")
            assertOrExit(yyyyMMdd(w.end) == "2026-12-24", "st_andrew_christmas 2026 end expected 2026-12-24, got \(yyyyMMdd(w.end))")
            assertOrExit(yyyyMMdd(w.feast) == "2026-12-25", "st_andrew_christmas 2026 feast expected 2026-12-25, got \(yyyyMMdd(w.feast))")
        } else {
            assertOrExit(false, "st_andrew_christmas 2026 window missing")
        }

        // Feast-tied convention example: starts 9 days before feast, ends vigil/day-before.
        if let w = ContentStore.novenaServingWindow(id: "st_joseph", year: 2026) {
            assertOrExit(yyyyMMdd(w.start) == "2026-03-10", "st_joseph 2026 start expected 2026-03-10, got \(yyyyMMdd(w.start))")
            assertOrExit(yyyyMMdd(w.end) == "2026-03-18", "st_joseph 2026 end expected 2026-03-18, got \(yyyyMMdd(w.end))")
            assertOrExit(yyyyMMdd(w.feast) == "2026-03-19", "st_joseph 2026 feast expected 2026-03-19, got \(yyyyMMdd(w.feast))")
        } else {
            assertOrExit(false, "st_joseph 2026 window missing")
        }

        print("PASS: novena serving rule checks")
    }
}
