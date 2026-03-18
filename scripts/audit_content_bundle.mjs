import fs from 'fs';
import path from 'path';

const root = '/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Resources';
const legacyRoot = path.join(root, 'LegacyData');
const saintsDir = path.join(legacyRoot, 'saints');
const novenasDir = path.join(legacyRoot, 'novenas');
const saintsIndex = readJSON(path.join(legacyRoot, 'saints_index.json'));

function readJSON(file) { return JSON.parse(fs.readFileSync(file, 'utf8')); }
function firstNonEmpty(...values) {
  for (const value of values) {
    const trimmed = String(value ?? '').trim();
    if (trimmed) return trimmed;
  }
  return '';
}

const novenaFiles = fs.readdirSync(novenasDir).filter(f => f.endsWith('.json')).sort();
const saints = saintsIndex.map(entry => readJSON(path.join(saintsDir, `${entry.id}.json`)));
const novenasAll = novenaFiles.map(f => readJSON(path.join(novenasDir, f)));
const novenasPublished = novenasAll.filter(doc => doc.status !== 'draft');
const prayers = readJSON(path.join(root, 'prayers.json'));
const saintsBundle = readJSON(path.join(root, 'saints.json'));
const novenasBundle = readJSON(path.join(root, 'novenas.json'));
const novenasIndex = readJSON(path.join(legacyRoot, 'novenas_index.json'));

const saintLocaleIssues = [];
for (const saint of saints) {
  const fields = [
    ['name', 'name_es', 'name_pl'],
    ['feast', 'feast_es', 'feast_pl'],
    ['summary', 'summary_es', 'summary_pl'],
    ['biography', 'biography_es', 'biography_pl']
  ];
  for (const [baseKey, esKey, plKey] of fields) {
    if (!firstNonEmpty(saint[baseKey])) saintLocaleIssues.push(`${saint.id}:${baseKey}:en`);
    if (!firstNonEmpty(saint[esKey])) saintLocaleIssues.push(`${saint.id}:${baseKey}:es`);
    if (!firstNonEmpty(saint[plKey])) saintLocaleIssues.push(`${saint.id}:${baseKey}:pl`);
  }
}

const saintMismatchGuards = {
  '02-28_saint_angela_of_foligno': ['Foligno Cathedral'],
  '05-03_saints_philip_and_james': ['Vilnius', 'Lukiškės'],
  '06-30_the_first_martyrs_of_the_holy_roman_church': ['camerlengo', 'Kevin Farrell'],
  '07-02_blessed_virgin_mary_to_elizabeth': ['Port Elizabeth', 'Anglican'],
  '08-06_the_transfiguration_of_the_lord': ['Ruma', 'Serbian Orthodox'],
  '03-02_saint_jovinus': ['Faustinus', 'Jovita'],
  '05-11_saint_evelius': ['Eulogius'],
  '08-29_the_passion_of_saint_john_the_baptist_martyr_memorial': ['A martyr is someone']
};
const saintMismatchHits = [];
for (const [id, needles] of Object.entries(saintMismatchGuards)) {
  const saint = saints.find(s => s.id === id);
  if (!saint) { saintMismatchHits.push(`${id}:missing`); continue; }
  const haystack = [saint.summary, saint.biography, saint.summary_es, saint.biography_es, saint.summary_pl, saint.biography_pl].join('\n');
  for (const needle of needles) {
    if (haystack.includes(needle)) saintMismatchHits.push(`${id}:${needle}`);
  }
}

const novenaIssues = { missingTop: [], missingDayLocale: [], emptyDesc: [], durationMismatch: [] };
for (const doc of novenasPublished) {
  for (const key of ['title','description']) {
    if (!firstNonEmpty(doc[key])) novenaIssues.missingTop.push(`${doc.id}:${key}:en`);
    if (!firstNonEmpty(doc[`${key}_es`])) novenaIssues.missingTop.push(`${doc.id}:${key}:es`);
    if (!firstNonEmpty(doc[`${key}_pl`])) novenaIssues.missingTop.push(`${doc.id}:${key}:pl`);
  }
  if (!firstNonEmpty(doc.description)) novenaIssues.emptyDesc.push(doc.id);
  if ((doc.days ?? []).length !== (doc.durationDays ?? (doc.days ?? []).length)) novenaIssues.durationMismatch.push(`${doc.id}:doc`);
  for (const day of doc.days ?? []) {
    for (const [baseKey, esKey, plKey] of [
      ['title','title_es','title_pl'],
      ['scripture','scripture_es','scripture_pl'],
      ['prayer','prayer_es','prayer_pl'],
      ['reflection','reflection_es','reflection_pl'],
    ]) {
      const base = firstNonEmpty(day[baseKey]);
      if (!base) continue;
      if (!firstNonEmpty(day[esKey])) novenaIssues.missingDayLocale.push(`${doc.id}:day${day.day}:${esKey}`);
      if (!firstNonEmpty(day[plKey])) novenaIssues.missingDayLocale.push(`${doc.id}:day${day.day}:${plKey}`);
    }
  }
}
for (const item of novenasBundle) {
  if (item.durationDays !== item.days.length) novenaIssues.durationMismatch.push(`${item.id}:bundle`);
}
for (const item of novenasIndex) {
  const bundleItem = novenasBundle.find(n => n.id === item.id);
  if (!bundleItem) novenaIssues.durationMismatch.push(`${item.id}:missingFromBundle`);
  else if (item.durationDays !== bundleItem.days.length) novenaIssues.durationMismatch.push(`${item.id}:index`);
}

const prayerIssues = [];
for (const prayer of prayers) {
  for (const locale of ['en','es','pl']) {
    if (!firstNonEmpty(prayer.titleByLocale?.[locale])) prayerIssues.push(`${prayer.id}:title:${locale}`);
    if (!firstNonEmpty(prayer.bodyByLocale?.[locale])) prayerIssues.push(`${prayer.id}:body:${locale}`);
  }
}

console.log(JSON.stringify({
  saints: { sourceCount: saints.length, bundleCount: saintsBundle.length, localeIssues: saintLocaleIssues.length, mismatchHits: saintMismatchHits },
  novenas: {
    sourceCount: novenasAll.length,
    publishedCount: novenasPublished.length,
    bundleCount: novenasBundle.length,
    missingTop: novenaIssues.missingTop.length,
    missingDayLocale: novenaIssues.missingDayLocale.length,
    emptyDesc: novenaIssues.emptyDesc,
    durationMismatch: novenaIssues.durationMismatch.length,
    unpublishedDrafts: novenasAll.filter(doc => doc.status === 'draft').map(doc => doc.id)
  },
  prayers: { bundleCount: prayers.length, issues: prayerIssues.length, details: prayerIssues }
}, null, 2));
