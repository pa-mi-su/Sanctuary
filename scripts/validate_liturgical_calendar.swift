#!/usr/bin/env swift
import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current

func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return components.date!
}

func addDays(_ date: Date, _ days: Int) -> Date {
    calendar.date(byAdding: .day, value: days, to: date)!
}

func easterSunday(_ year: Int) -> Date {
    let a = year % 19
    let b = year / 100
    let c = year % 100
    let d = b / 4
    let e = b % 4
    let f = (b + 8) / 25
    let g = (b - f + 1) / 3
    let h = (19 * a + b - d - g + 15) % 30
    let i = c / 4
    let k = c % 4
    let l = (32 + 2 * e + 2 * i - h - k) % 7
    let m = (a + 11 * h + 22 * l) / 451
    let month = (h + l - 7 * m + 114) / 31
    let day = ((h + l - 7 * m + 114) % 31) + 1
    return makeDate(year, month, day)
}

func ymd(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

func weekday(_ date: Date) -> Int {
    calendar.component(.weekday, from: date) // 1=Sun...7=Sat
}

struct KnownDate {
    let year: Int
    let easter: String
    let goodFriday: String
}

let known: [KnownDate] = [
    .init(year: 1900, easter: "1900-04-15", goodFriday: "1900-04-13"),
    .init(year: 1954, easter: "1954-04-18", goodFriday: "1954-04-16"),
    .init(year: 2000, easter: "2000-04-23", goodFriday: "2000-04-21"),
    .init(year: 2018, easter: "2018-04-01", goodFriday: "2018-03-30"),
    .init(year: 2026, easter: "2026-04-05", goodFriday: "2026-04-03"),
    .init(year: 2027, easter: "2027-03-28", goodFriday: "2027-03-26"),
    .init(year: 2100, easter: "2100-03-28", goodFriday: "2100-03-26"),
]

var failures: [String] = []

for item in known {
    let easter = easterSunday(item.year)
    let goodFriday = addDays(easter, -2)
    let easterYmd = ymd(easter)
    let gfYmd = ymd(goodFriday)
    if easterYmd != item.easter {
        failures.append("Known-date mismatch for \(item.year): Easter expected \(item.easter), got \(easterYmd)")
    }
    if gfYmd != item.goodFriday {
        failures.append("Known-date mismatch for \(item.year): Good Friday expected \(item.goodFriday), got \(gfYmd)")
    }
}

for year in 1900...4099 {
    let easter = easterSunday(year)
    let goodFriday = addDays(easter, -2)

    if weekday(easter) != 1 {
        failures.append("Weekday mismatch for \(year): Easter is not Sunday (\(ymd(easter)))")
    }
    if weekday(goodFriday) != 6 {
        failures.append("Weekday mismatch for \(year): Good Friday is not Friday (\(ymd(goodFriday)))")
    }
}

if failures.isEmpty {
    print("PASS: liturgical calendar checks passed for years 1900...4099")
    exit(0)
}

for failure in failures {
    fputs("FAIL: \(failure)\n", stderr)
}
exit(1)
