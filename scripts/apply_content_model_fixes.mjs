import fs from 'fs';

function update(file, transform) {
  const before = fs.readFileSync(file, 'utf8');
  const after = transform(before);
  if (after === before) throw new Error(`No changes made in ${file}`);
  fs.writeFileSync(file, after);
}
function replaceOnce(source, search, replacement, label) {
  if (!source.includes(search)) throw new Error(`Missing pattern: ${label}`);
  return source.replace(search, replacement);
}

update('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Core/Domain/Entities.swift', source => {
  source = replaceOnce(source,
`    let name: String
    let feastMonth: Int`,
`    let name: String
    let nameByLocale: [ContentLocale: String]
    let feastMonth: Int`,
'Entities Saint.nameByLocale');
  source = replaceOnce(source,
`    let prayersByLocale: [ContentLocale: [String]]
    let sources: [String]
}`,
`    let prayersByLocale: [ContentLocale: [String]]
    let sources: [String]

    func displayName(locale: ContentLocale) -> String {
        let localized = nameByLocale[locale] ?? nameByLocale[.en] ?? name
        return localized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}`,
'Entities displayName');
  return source;
});

update('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Core/Data/Local/LocalContentRepository.swift', source => {
  source = replaceOnce(source,
`                let name = saint.name.lowercased()
                let biography = saint.biographyByLocale[locale]?.lowercased() ?? ""
                return name.contains(normalized) || biography.contains(normalized)
            }
            .sorted { $0.name < $1.name }`,
`                let name = saint.displayName(locale: locale).lowercased()
                let biography = saint.biographyByLocale[locale]?.lowercased() ?? ""
                return name.contains(normalized) || biography.contains(normalized)
            }
            .sorted { $0.displayName(locale: locale) < $1.displayName(locale: locale) }`,
'LocalContentRepository listSaints');
  source = replaceOnce(source,
`            name: "Saint Joseph",
            feastMonth: 3,`,
`            name: "Saint Joseph",
            nameByLocale: [.en: "Saint Joseph", .es: "San José", .pl: "Święty Józef"],
            feastMonth: 3,`,
'LocalSeed Saint Joseph');
  source = replaceOnce(source,
`            name: "Saint Faustina",
            feastMonth: 10,`,
`            name: "Saint Faustina",
            nameByLocale: [.en: "Saint Faustina", .es: "Santa Faustina", .pl: "Święta Faustyna"],
            feastMonth: 10,`,
'LocalSeed Saint Faustina');
  source = replaceOnce(source,
`        let summaryByLocale = localizedMap(base: doc.summary, es: doc.summary_es, pl: doc.summary_pl)
        let biographyByLocale = localizedMap(base: doc.biography, es: doc.biography_es, pl: doc.biography_pl)
        let feastByLocale = localizedMap(base: doc.feast, es: doc.feast_es, pl: doc.feast_pl)
`,
`        let nameByLocale = localizedMap(base: doc.name, es: doc.name_es, pl: doc.name_pl)
        let summaryByLocale = localizedMap(base: doc.summary, es: doc.summary_es, pl: doc.summary_pl)
        let biographyByLocale = localizedMap(base: doc.biography, es: doc.biography_es, pl: doc.biography_pl)
        let feastByLocale = localizedMap(base: doc.feast, es: doc.feast_es, pl: doc.feast_pl)
`,
'LocalContentRepository mapSourceSaint locals');
  source = replaceOnce(source,
`            name: doc.name ?? doc.id,
            feastMonth: month,`,
`            name: nameByLocale[.en] ?? doc.id,
            nameByLocale: nameByLocale,
            feastMonth: month,`,
'LocalContentRepository mapSourceSaint init');
  return source;
});

update('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Saints/SaintsListViewModel.swift', source => {
  source = replaceOnce(source,
`    func summary(for saint: Saint) -> String {
        saint.summaryByLocale[locale] ?? saint.summaryByLocale[.en] ?? ""
    }
`,
`    func summary(for saint: Saint) -> String {
        saint.summaryByLocale[locale] ?? saint.summaryByLocale[.en] ?? ""
    }

    func displayName(for saint: Saint) -> String {
        saint.displayName(locale: locale)
    }
`,
'SaintsListViewModel displayName');
  source = replaceOnce(source,
`            let blob = "\(saint.name) \(saint.slug) \(summary) \(bio)"`,
`            let blob = "\(saint.displayName(locale: locale)) \(saint.slug) \(summary) \(bio)"`,
'SaintsListViewModel blob');
  return source;
});

update('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Search/SearchViews.swift', source => {
  return replaceOnce(source,
`                        Text(saint.name).font(.headline)`,
`                        Text(viewModel.displayName(for: saint)).font(.headline)`,
'SearchViews saint name');
});

update('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Saints/SaintsListView.swift', source => {
  return replaceOnce(source,
`                            Text(saint.name)`,
`                            Text(viewModel.displayName(for: saint))`,
'SaintsListView saint name');
});

update('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Novenas/NovenaDetailView.swift', source => {
  source = replaceOnce(source,
`                                        Text(saint.name)`,
`                                        Text(saint.displayName(locale: localization.language.contentLocale))`,
'NovenaDetail related saint button');
  source = replaceOnce(source,
`                    name: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id,
                    feastMonth: 1,`,
`                    name: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id,
                    nameByLocale: [.en: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id, .es: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id, .pl: relatedSaints.first(where: { $0.id == selection.id })?.name ?? selection.id],
                    feastMonth: 1,`,
'NovenaDetail placeholder saint');
  source = replaceOnce(source,
`        return Saint(
            id: doc.id,
            slug: doc.id,
            name: doc.name ?? doc.id,
            feastMonth: month,`,
`        let nameByLocale: [ContentLocale: String] = [.en: doc.name ?? doc.id, .es: doc.name_es ?? doc.name ?? doc.id, .pl: doc.name_pl ?? doc.name ?? doc.id]
        return Saint(
            id: doc.id,
            slug: doc.id,
            name: nameByLocale[.en] ?? doc.id,
            nameByLocale: nameByLocale,
            feastMonth: month,`,
'NovenaDetail mapSourceSaint');
  return source;
});

update('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Me/MeView.swift', source => {
  source = replaceOnce(source,
`                        name: saintName(for: id),
                        feastMonth: 1,`,
`                        name: saintName(for: id),
                        nameByLocale: [.en: saintName(for: id), .es: saintName(for: id), .pl: saintName(for: id)],
                        feastMonth: 1,`,
'MeView placeholder saint');
  source = replaceOnce(source,
`        return Saint(
            id: doc.id,
            slug: doc.id,
            name: doc.name ?? doc.id,
            feastMonth: month,`,
`        let nameByLocale: [ContentLocale: String] = [.en: doc.name ?? doc.id, .es: doc.name_es ?? doc.name ?? doc.id, .pl: doc.name_pl ?? doc.name ?? doc.id]
        return Saint(
            id: doc.id,
            slug: doc.id,
            name: nameByLocale[.en] ?? doc.id,
            nameByLocale: nameByLocale,
            feastMonth: month,`,
'MeView mapSourceSaint');
  return source;
});

update('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Calendar/CalendarViews.swift', source => {
  source = replaceOnce(source,
`                if let id = ContentStore.firstSaintID(onMonth: month, day: day) {
                    ids[day] = id
                }
                if let name = ContentStore.firstSaintName(onMonth: month, day: day) {
                    names[day] = name
                }
`,
`                if let id = ContentStore.firstSaintID(onMonth: month, day: day) {
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
`,
'Calendar loadSaintLookups localization');
  source = replaceOnce(source,
`                    name: saintNameByDay[selectedDay] ?? localization.t("tab.saints"),
                    feastMonth: selectedMonth,`,
`                    name: saintNameByDay[selectedDay] ?? localization.t("tab.saints"),
                    nameByLocale: [.en: saintNameByDay[selectedDay] ?? localization.t("tab.saints"), .es: saintNameByDay[selectedDay] ?? localization.t("tab.saints"), .pl: saintNameByDay[selectedDay] ?? localization.t("tab.saints")],
                    feastMonth: selectedMonth,`,
'Calendar placeholder saint');
  source = replaceOnce(source,
`    return Saint(
        id: doc.id,
        slug: doc.id,
        name: doc.name ?? doc.id,
        feastMonth: month,`,
`    let nameByLocale: [ContentLocale: String] = [.en: doc.name ?? doc.id, .es: doc.name_es ?? doc.name ?? doc.id, .pl: doc.name_pl ?? doc.name ?? doc.id]
    return Saint(
        id: doc.id,
        slug: doc.id,
        name: nameByLocale[.en] ?? doc.id,
        nameByLocale: nameByLocale,
        feastMonth: month,`,
'Calendar mapSourceSaint');
  return source;
});

update('/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Features/Saints/SaintDetailView.swift', source => {
  return replaceOnce(source,
`        let baseName = localized(base: sourceDoc?.name, es: sourceDoc?.name_es, pl: sourceDoc?.name_pl) ?? saint.name`,
`        let baseName = localized(base: sourceDoc?.name, es: sourceDoc?.name_es, pl: sourceDoc?.name_pl) ?? saint.displayName(locale: locale)`,
'SaintDetailView displayName');
});

console.log('Applied Swift model/localization fixes.');
