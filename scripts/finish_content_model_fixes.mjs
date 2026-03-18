import fs from 'fs';
function patch(file, replacements) {
  let s = fs.readFileSync(file, 'utf8');
  for (const [search, replacement] of replacements) {
    if (s.includes(replacement)) continue;
    if (!s.includes(search)) throw new Error(`Missing pattern in ${file}: ${search.slice(0,80)}`);
    s = s.replace(search, replacement);
  }
  fs.writeFileSync(file, s);
}
patch('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Saints/SaintsListViewModel.swift', [
[`    func summary(for saint: Saint) -> String {
        saint.summaryByLocale[locale] ?? saint.summaryByLocale[.en] ?? ""
    }
`, `    func summary(for saint: Saint) -> String {
        saint.summaryByLocale[locale] ?? saint.summaryByLocale[.en] ?? ""
    }

    func displayName(for saint: Saint) -> String {
        saint.displayName(locale: locale)
    }
`],
[`            let blob = "\(saint.name) \(saint.slug) \(summary) \(bio)"`, `            let blob = "\(saint.displayName(locale: locale)) \(saint.slug) \(summary) \(bio)"`]
]);
patch('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Search/SearchViews.swift', [[`                        Text(saint.name).font(.headline)`, `                        Text(viewModel.displayName(for: saint)).font(.headline)`]]);
patch('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Saints/SaintsListView.swift', [[`                            Text(saint.name)`, `                            Text(viewModel.displayName(for: saint))`]]);
patch('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Saints/SaintDetailView.swift', [[`        let baseName = localized(base: sourceDoc?.name, es: sourceDoc?.name_es, pl: sourceDoc?.name_pl) ?? saint.name`, `        let baseName = localized(base: sourceDoc?.name, es: sourceDoc?.name_es, pl: sourceDoc?.name_pl) ?? saint.displayName(locale: locale)`]]);
patch('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Novenas/NovenaDetailView.swift', [
[`                                        Text(saint.name)`, `                                        Text(saint.displayName(locale: localization.language.contentLocale))`],
[`                    name: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id,
                    feastMonth: 1,`, `                    name: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id,
                    nameByLocale: [.en: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id, .es: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id, .pl: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id],
                    feastMonth: 1,`],
[`        return Saint(
            id: doc.id,
            slug: doc.id,
            name: doc.name ?? doc.id,
            feastMonth: month,`, `        let nameByLocale: [ContentLocale: String] = [.en: doc.name ?? doc.id, .es: doc.name_es ?? doc.name ?? doc.id, .pl: doc.name_pl ?? doc.name ?? doc.id]
        return Saint(
            id: doc.id,
            slug: doc.id,
            name: nameByLocale[.en] ?? doc.id,
            nameByLocale: nameByLocale,
            feastMonth: month,`]
]);
patch('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Me/MeView.swift', [
[`                        name: saintName(for: id),
                        feastMonth: 1,`, `                        name: saintName(for: id),
                        nameByLocale: [.en: saintName(for: id), .es: saintName(for: id), .pl: saintName(for: id)],
                        feastMonth: 1,`],
[`        return Saint(
            id: doc.id,
            slug: doc.id,
            name: doc.name ?? doc.id,
            feastMonth: month,`, `        let nameByLocale: [ContentLocale: String] = [.en: doc.name ?? doc.id, .es: doc.name_es ?? doc.name ?? doc.id, .pl: doc.name_pl ?? doc.name ?? doc.id]
        return Saint(
            id: doc.id,
            slug: doc.id,
            name: nameByLocale[.en] ?? doc.id,
            nameByLocale: nameByLocale,
            feastMonth: month,`]
]);
patch('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Calendar/CalendarViews.swift', [
[`                if let id = ContentStore.firstSaintID(onMonth: month, day: day) {
                    ids[day] = id
                }
                if let name = ContentStore.firstSaintName(onMonth: month, day: day) {
                    names[day] = name
                }
`, `                if let id = ContentStore.firstSaintID(onMonth: month, day: day) {
                    ids[day] = id
                    if let doc = ContentStore.saint(id: id) {
                        let name: String
                        switch localization.language.contentLocale {
                        case .en:
                            name = doc.name ?? id
                        case .es:
                            name = doc.name_es ?? doc.name ?? id
                        case .pl:
                            name = doc.name_pl ?? doc.name ?? id
                        }
                        names[day] = name
                    }
                }
`],
[`                    name: saintNameByDay[selectedDay] ?? localization.t("tab.saints"),
                    feastMonth: selectedMonth,`, `                    name: saintNameByDay[selectedDay] ?? localization.t("tab.saints"),
                    nameByLocale: [.en: saintNameByDay[selectedDay] ?? localization.t("tab.saints"), .es: saintNameByDay[selectedDay] ?? localization.t("tab.saints"), .pl: saintNameByDay[selectedDay] ?? localization.t("tab.saints")],
                    feastMonth: selectedMonth,`],
[`    return Saint(
        id: doc.id,
        slug: doc.id,
        name: doc.name ?? doc.id,
        feastMonth: month,`, `    let nameByLocale: [ContentLocale: String] = [.en: doc.name ?? doc.id, .es: doc.name_es ?? doc.name ?? doc.id, .pl: doc.name_pl ?? doc.name ?? doc.id]
    return Saint(
        id: doc.id,
        slug: doc.id,
        name: nameByLocale[.en] ?? doc.id,
        nameByLocale: nameByLocale,
        feastMonth: month,`]
]);
console.log('Finished Swift model/UI localization fixes.');
