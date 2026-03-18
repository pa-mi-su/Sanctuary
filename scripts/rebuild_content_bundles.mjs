import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

const root = '/Users/pms/Documents/Projects/Sanctuary/Sanctuary/Resources';
const legacyRoot = path.join(root, 'LegacyData');
const saintsDir = path.join(legacyRoot, 'saints');
const novenasDir = path.join(legacyRoot, 'novenas');
const prayersDir = path.join(legacyRoot, 'prayers');
const repoRoot = '/Users/pms/Documents/Projects/Sanctuary';

function readJSON(file) { return JSON.parse(fs.readFileSync(file, 'utf8')); }
function writeJSON(file, value) { fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`); }
function firstNonEmpty(...values) {
  for (const value of values) {
    const trimmed = String(value ?? '').trim();
    if (trimmed) return trimmed;
  }
  return '';
}
function urlOrNull(raw) {
  const value = firstNonEmpty(raw);
  return value || null;
}
function localeMap(base, es, pl) {
  const en = firstNonEmpty(base);
  return { en, es: firstNonEmpty(es, en), pl: firstNonEmpty(pl, en) };
}
function monthDay(mmdd) {
  const [month, day] = String(mmdd || '01-01').split('-').map(v => Number(v));
  return { month: month || 1, day: day || 1 };
}
function loadHeadJSON(relPath) {
  const raw = execSync(`git -C ${repoRoot} show HEAD:${relPath}`, { encoding: 'utf8' });
  return JSON.parse(raw);
}
const saintDocsById = new Map(fs.readdirSync(saintsDir).filter(f => f.endsWith('.json')).sort().map(f => {
  const doc = readJSON(path.join(saintsDir, f));
  return [doc.id, doc];
}));
function isPublishedNovena(doc) {
  if (doc.status === 'draft') return false;
  const desc = firstNonEmpty(doc.description);
  const descEs = firstNonEmpty(doc.description_es);
  const descPl = firstNonEmpty(doc.description_pl);
  if (!desc || !descEs || !descPl) return false;
  if (!Array.isArray(doc.days) || doc.days.length === 0) return false;
  for (const day of doc.days) {
    for (const [baseKey, esKey, plKey] of [
      ['title','title_es','title_pl'],
      ['scripture','scripture_es','scripture_pl'],
      ['prayer','prayer_es','prayer_pl'],
      ['reflection','reflection_es','reflection_pl'],
    ]) {
      const base = firstNonEmpty(day[baseKey]);
      if (!base) continue;
      if (!firstNonEmpty(day[esKey]) || !firstNonEmpty(day[plKey])) return false;
    }
  }
  return true;
}
const novenaDocsById = new Map(fs.readdirSync(novenasDir).filter(f => f.endsWith('.json')).sort().map(f => {
  const doc = readJSON(path.join(novenasDir, f));
  return [doc.id, doc];
}));
const prayerDocsById = new Map(fs.readdirSync(prayersDir).filter(f => f.endsWith('.json')).sort().map(f => {
  const doc = readJSON(path.join(prayersDir, f));
  return [doc.id, doc];
}));

const canonicalSaintIndex = loadHeadJSON('Sanctuary/Resources/LegacyData/saints_index.json');
const saintSource = canonicalSaintIndex.map(entry => saintDocsById.get(entry.id)).filter(Boolean).sort((a,b) => (a.mmdd||'').localeCompare(b.mmdd||'') || a.id.localeCompare(b.id));
const saintsIndex = saintSource.map(doc => ({ id: doc.id, name: firstNonEmpty(doc.name, doc.id), mmdd: doc.mmdd ?? '01-01', feast: firstNonEmpty(doc.feast) }));
const saints = saintSource.map(doc => {
  const {month, day} = monthDay(doc.mmdd);
  const nameByLocale = localeMap(doc.name, doc.name_es, doc.name_pl);
  return {
    id: doc.id,
    slug: doc.id,
    name: nameByLocale.en,
    nameByLocale,
    feastMonth: month,
    feastDay: day,
    imageURL: urlOrNull(doc.photoUrl),
    tags: [],
    patronages: [],
    feastLabelByLocale: localeMap(doc.feast, doc.feast_es, doc.feast_pl),
    summaryByLocale: localeMap(doc.summary, doc.summary_es, doc.summary_pl),
    biographyByLocale: localeMap(doc.biography, doc.biography_es, doc.biography_pl),
    prayersByLocale: { en: doc.prayers ?? [], es: doc.prayers ?? [], pl: doc.prayers ?? [] },
    sources: Array.isArray(doc.sources) ? doc.sources : []
  };
});

const canonicalNovenaIndex = loadHeadJSON('Sanctuary/Resources/LegacyData/novenas_index.json');
const novenaSource = canonicalNovenaIndex.map(entry => novenaDocsById.get(entry.id)).filter(Boolean).filter(isPublishedNovena);
const novenasIndex = novenaSource.map(doc => ({
  id: doc.id,
  title: firstNonEmpty(doc.title, doc.id),
  startRule: doc.startRule ?? null,
  feastRule: doc.feastRule ?? null,
  durationDays: (doc.days ?? []).length,
  category: doc.category ?? null,
  tags: doc.tags ?? [],
  description: firstNonEmpty(doc.description),
  patronage: doc.patronage ?? [],
  image: doc.image ?? null,
  notes: doc.notes ?? null,
  source: doc.source ?? null,
}));
const novenas = novenaSource.map(doc => ({
  id: doc.id,
  slug: doc.id,
  titleByLocale: localeMap(doc.title, doc.title_es, doc.title_pl),
  descriptionByLocale: localeMap(doc.description, doc.description_es, doc.description_pl),
  durationDays: (doc.days ?? []).length,
  tags: doc.tags ?? [],
  imageURL: urlOrNull(doc.image),
  days: (doc.days ?? []).map(day => {
    const titleByLocale = localeMap(day.title, day.title_es, day.title_pl);
    const scriptureByLocale = localeMap(day.scripture, day.scripture_es, day.scripture_pl);
    const prayerByLocale = localeMap(day.prayer, day.prayer_es, day.prayer_pl);
    const reflectionByLocale = localeMap(day.reflection, day.reflection_es, day.reflection_pl);
    const bodyByLocale = {
      en: [titleByLocale.en, scriptureByLocale.en, prayerByLocale.en, reflectionByLocale.en].filter(Boolean).join('\n\n'),
      es: [titleByLocale.es, scriptureByLocale.es, prayerByLocale.es, reflectionByLocale.es].filter(Boolean).join('\n\n'),
      pl: [titleByLocale.pl, scriptureByLocale.pl, prayerByLocale.pl, reflectionByLocale.pl].filter(Boolean).join('\n\n'),
    };
    return { dayNumber: day.day, titleByLocale, scriptureByLocale, prayerByLocale, reflectionByLocale, bodyByLocale };
  })
}));

const canonicalPrayerIndex = loadHeadJSON('Sanctuary/Resources/LegacyData/prayers_index.json');
const prayerSource = canonicalPrayerIndex.map(entry => prayerDocsById.get(entry.id)).filter(Boolean);
const prayersIndex = prayerSource.map(doc => ({ id: doc.id, title: firstNonEmpty(doc.title, doc.id) }));
const prayers = prayerSource.map(doc => ({
  id: doc.id,
  slug: doc.id,
  category: firstNonEmpty(doc.source?.type, 'general'),
  titleByLocale: localeMap(doc.title, doc.title_es, doc.title_pl),
  bodyByLocale: localeMap(doc.prayerText, doc.prayerText_es, doc.prayerText_pl),
  tags: []
}));

writeJSON(path.join(legacyRoot, 'saints_index.json'), saintsIndex);
writeJSON(path.join(legacyRoot, 'novenas_index.json'), novenasIndex);
writeJSON(path.join(legacyRoot, 'prayers_index.json'), prayersIndex);
writeJSON(path.join(root, 'saints.json'), saints);
writeJSON(path.join(root, 'novenas.json'), novenas);
writeJSON(path.join(root, 'prayers.json'), prayers);

console.log(JSON.stringify({ saints: saints.length, novenas: novenas.length, prayers: prayers.length }, null, 2));
