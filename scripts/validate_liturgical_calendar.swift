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
    let holyThursday: String
    let goodFriday: String
    let ashWednesday: String
    let palmSunday: String
}

let known: [KnownDate] = [
    .init(year: 1900, easter: "1900-04-15", holyThursday: "1900-04-12", goodFriday: "1900-04-13", ashWednesday: "1900-02-28", palmSunday: "1900-04-08"),
    .init(year: 1954, easter: "1954-04-18", holyThursday: "1954-04-15", goodFriday: "1954-04-16", ashWednesday: "1954-03-03", palmSunday: "1954-04-11"),
    .init(year: 2000, easter: "2000-04-23", holyThursday: "2000-04-20", goodFriday: "2000-04-21", ashWednesday: "2000-03-08", palmSunday: "2000-04-16"),
    .init(year: 2018, easter: "2018-04-01", holyThursday: "2018-03-29", goodFriday: "2018-03-30", ashWednesday: "2018-02-14", palmSunday: "2018-03-25"),
    .init(year: 2026, easter: "2026-04-05", holyThursday: "2026-04-02", goodFriday: "2026-04-03", ashWednesday: "2026-02-18", palmSunday: "2026-03-29"),
    .init(year: 2027, easter: "2027-03-28", holyThursday: "2027-03-25", goodFriday: "2027-03-26", ashWednesday: "2027-02-10", palmSunday: "2027-03-21"),
    .init(year: 2100, easter: "2100-03-28", holyThursday: "2100-03-25", goodFriday: "2100-03-26", ashWednesday: "2100-02-10", palmSunday: "2100-03-21"),
]

var failures: [String] = []

for item in known {
    let easter = easterSunday(item.year)
    let holyThursday = addDays(easter, -3)
    let goodFriday = addDays(easter, -2)
    let ashWednesday = addDays(easter, -46)
    let palmSunday = addDays(easter, -7)
    let easterYmd = ymd(easter)
    let holyThursdayYmd = ymd(holyThursday)
    let gfYmd = ymd(goodFriday)
    let ashWednesdayYmd = ymd(ashWednesday)
    let palmSundayYmd = ymd(palmSunday)
    if easterYmd != item.easter {
        failures.append("Known-date mismatch for \(item.year): Easter expected \(item.easter), got \(easterYmd)")
    }
    if holyThursdayYmd != item.holyThursday {
        failures.append("Known-date mismatch for \(item.year): Holy Thursday expected \(item.holyThursday), got \(holyThursdayYmd)")
    }
    if gfYmd != item.goodFriday {
        failures.append("Known-date mismatch for \(item.year): Good Friday expected \(item.goodFriday), got \(gfYmd)")
    }
    if ashWednesdayYmd != item.ashWednesday {
        failures.append("Known-date mismatch for \(item.year): Ash Wednesday expected \(item.ashWednesday), got \(ashWednesdayYmd)")
    }
    if palmSundayYmd != item.palmSunday {
        failures.append("Known-date mismatch for \(item.year): Palm Sunday expected \(item.palmSunday), got \(palmSundayYmd)")
    }
}

for year in 1900...4099 {
    let easter = easterSunday(year)
    let holyThursday = addDays(easter, -3)
    let goodFriday = addDays(easter, -2)
    let ashWednesday = addDays(easter, -46)
    let palmSunday = addDays(easter, -7)

    if weekday(easter) != 1 {
        failures.append("Weekday mismatch for \(year): Easter is not Sunday (\(ymd(easter)))")
    }
    if weekday(holyThursday) != 5 {
        failures.append("Weekday mismatch for \(year): Holy Thursday is not Thursday (\(ymd(holyThursday)))")
    }
    if weekday(goodFriday) != 6 {
        failures.append("Weekday mismatch for \(year): Good Friday is not Friday (\(ymd(goodFriday)))")
    }
    if weekday(ashWednesday) != 4 {
        failures.append("Weekday mismatch for \(year): Ash Wednesday is not Wednesday (\(ymd(ashWednesday)))")
    }
    if weekday(palmSunday) != 1 {
        failures.append("Weekday mismatch for \(year): Palm Sunday is not Sunday (\(ymd(palmSunday)))")
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
