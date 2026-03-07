#!/usr/bin/env python3
import html
import json
import re
import time
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen


INDEX_URL = "https://novenaprayer.com/novena-prayers/"
INTENTIONS_URL = "https://novenaprayer.com/novenas-by-intentions/"
ROOT = Path(__file__).resolve().parents[1]
NOVENAS_DIR = ROOT / "Sanctuary" / "Resources" / "LegacyData" / "novenas"


def read_text_with_retry(path: Path, attempts: int = 5) -> str:
    last = None
    for i in range(attempts):
        try:
            return path.read_text(encoding="utf-8")
        except OSError as exc:
            last = exc
            time.sleep(0.4 * (i + 1))
    raise last  # type: ignore[misc]


def write_text_with_retry(path: Path, payload: str, attempts: int = 5) -> None:
    last = None
    for i in range(attempts):
        try:
            path.write_text(payload, encoding="utf-8")
            return
        except OSError as exc:
            last = exc
            time.sleep(0.4 * (i + 1))
    raise last  # type: ignore[misc]


def fetch(url: str, timeout: int = 10) -> str:
    req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="ignore")


def strip_tags(text: str) -> str:
    text = re.sub(r"<br\s*/?>", " ", text, flags=re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    return " ".join(text.split())


def normalize(s: str) -> str:
    s = s.lower().replace("&", " and ").replace("st.", "saint ")
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    s = re.sub(r"\b(novena|prayer)\b", " ", s)
    return " ".join(s.split())


def tokenize(s: str) -> set[str]:
    stop = {"the", "of", "to", "and", "our", "lady", "for", "in", "on", "a"}
    return {w for w in normalize(s).split() if w and w not in stop}


def canonical_slugish(s: str) -> str:
    s = (s or "").lower()
    s = s.strip().strip("/")
    s = s.replace("_", "-")
    s = re.sub(r"^day-\d+-", "", s)
    s = re.sub(r"^novena-to-", "", s)
    s = re.sub(r"^novena-for-", "", s)
    s = re.sub(r"^novena-", "", s)
    s = re.sub(r"^saint-", "st-", s)
    s = re.sub(r"-novena$", "", s)
    s = re.sub(r"-prayer$", "", s)
    s = re.sub(r"[^a-z0-9-]", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    return s


def clean_intentions_text(raw: str) -> str:
    s = html.unescape((raw or "").strip())
    s = re.sub(r"\s+", " ", s).strip(" .;:-")
    for marker in [" Day 1", " About ", " Let us begin", " Novena Let us begin", " Name Meaning:"]:
        idx = s.find(marker)
        if idx > 0:
            s = s[:idx].strip(" .;:-")
    return s


def split_intentions(raw: str) -> list[str]:
    s = clean_intentions_text(raw).strip(".")
    s = re.sub(r"^\s*(patron saint of|patron st\. of|patron of)\s*", "", s, flags=re.I)
    parts = re.split(r",|;", s, flags=re.I)
    out, seen = [], set()
    for part in parts:
        value = " ".join(part.split()).strip(" .-")
        if len(value) < 2:
            continue
        key = normalize(value)
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(value)
    return out


def extract_links(index_html: str) -> list[str]:
    links = set()
    for m in re.finditer(r'href=["\']([^"\']+)["\']', index_html, flags=re.I):
        raw = m.group(1).strip()
        full = urljoin(INDEX_URL, raw).split("#")[0]
        if not full.startswith("https://novenaprayer.com/"):
            continue
        path = urlparse(full).path.lower()
        if "novena" not in path or not path.endswith("/"):
            continue
        slug = path.strip("/").split("/")[-1]
        if not slug:
            continue
        if not (
            slug.endswith("novena")
            or slug.startswith("novena-")
            or "novena-to-" in slug
            or slug in {"54-day-rosary-novena", "christmas-novena", "easter-novena"}
        ):
            continue
        if any(x in path for x in ["/category/", "/tag/", "/author/", "/feed", "/comment-page-", "/novenas-by-intentions/"]):
            continue
        links.add(full.rstrip("/") + "/")
    return sorted(links)


def extract_intentions_from_index_tables(index_html: str) -> list[tuple[str, str, list[str]]]:
    rows: list[tuple[str, str, list[str]]] = []
    tables = re.findall(r"<table[^>]*>(.*?)</table>", index_html, flags=re.I | re.S)
    for table in tables:
        title_match = re.search(r'<a[^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)</a>', table, flags=re.I | re.S)
        if not title_match:
            continue
        url = urljoin(INDEX_URL, title_match.group(1))
        title = strip_tags(title_match.group(2))
        if "noven" not in title.lower():
            continue

        cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", table, flags=re.I | re.S)
        if not cells:
            continue
        intentions_raw = strip_tags(cells[-1])
        intentions = split_intentions(intentions_raw)
        if intentions:
            rows.append((url, title, intentions))
    return rows


def extract_title(page_html: str, url: str) -> str:
    h1 = re.search(r"<h1[^>]*>(.*?)</h1>", page_html, flags=re.I | re.S)
    if h1:
        title = strip_tags(h1.group(1))
        if title:
            return title
    og = re.search(r'<meta property="og:title" content="([^"]+)"', page_html, flags=re.I)
    if og:
        return strip_tags(og.group(1).split(" - ")[0])
    slug = urlparse(url).path.strip("/").split("/")[-1]
    return slug.replace("-", " ").title()


def extract_intentions_from_page(page_html: str) -> list[str]:
    tables = re.findall(r"<table[^>]*>(.*?)</table>", page_html, flags=re.I | re.S)
    for table in tables:
        rows = re.findall(r"<tr[^>]*>(.*?)</tr>", table, flags=re.I | re.S)
        for row in rows:
            cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row, flags=re.I | re.S)
            if len(cells) >= 2:
                key = strip_tags(cells[0]).lower()
                value = strip_tags(cells[-1])
                if ("patron" in key or "intention" in key) and value:
                    return split_intentions(value)
        cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", table, flags=re.I | re.S)
        if cells:
            value = strip_tags(cells[-1])
            if "patron" in value.lower() or "intention" in value.lower():
                return split_intentions(value)

    text = strip_tags(page_html)
    patron = re.search(r"Patron Saint of ([^.]+)", text, flags=re.I) or re.search(r"Patron of ([^.]+)", text, flags=re.I)
    if patron:
        return split_intentions(patron.group(1))

    og = re.search(r"Patron St\. of ([^<\n]+)", page_html, flags=re.I)
    if og:
        return split_intentions(strip_tags(og.group(1)))
    return []


def best_match(page_title: str, page_url: str, local_items: list[dict]) -> tuple[dict | None, float]:
    page_tokens = tokenize(page_title) | tokenize(urlparse(page_url).path.replace("-", " "))
    page_slug = canonical_slugish(urlparse(page_url).path.strip("/").split("/")[-1])
    title_norm = normalize(page_title)

    # 1) Prefer strict slug mapping.
    slug_candidates = []
    for item in local_items:
        for key in item["slug_keys"]:
            if not key:
                continue
            if page_slug == key or page_slug.endswith("-" + key) or key.endswith("-" + page_slug):
                slug_candidates.append(item)
                break
    if len(slug_candidates) == 1:
        return slug_candidates[0], 1.0

    # 2) Then strict title containment.
    title_candidates = []
    for item in local_items:
        item_title_norm = normalize(item["title"])
        if len(item_title_norm) < 8:
            continue
        if item_title_norm in title_norm or title_norm in item_title_norm:
            title_candidates.append(item)
    if len(title_candidates) == 1:
        return title_candidates[0], 0.8

    # 3) Conservative fallback: only accept very strong token overlap.
    best, best_score = None, 0.0
    for item in local_items:
        local_tokens = item["tokens"]
        if not local_tokens:
            continue
        inter = len(page_tokens & local_tokens)
        union = len(page_tokens | local_tokens)
        score = inter / union if union else 0.0
        if page_slug and page_slug in item["slug_keys"]:
            score += 0.40
        if normalize(item["id"].replace("_", " ")) in normalize(page_url):
            score += 0.25
        if normalize(item["title"]) in normalize(page_title):
            score += 0.15
        if inter >= 3 and score > best_score:
            best, best_score = item, score
    if best_score >= 0.72:
        return (best, best_score)
    return (None, 0.0)


def extract_from_intentions_page(page_html: str) -> list[tuple[str, str, list[str]]]:
    rows = []
    li_blocks = re.findall(r"<li\b[^>]*>(.*?)</li>", page_html, flags=re.I | re.S)
    for li in li_blocks:
        a = re.search(r'<a[^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)</a>', li, flags=re.I | re.S)
        if not a:
            continue
        url = a.group(1)
        title = strip_tags(a.group(2))
        line_text = strip_tags(li)
        if "noven" not in title.lower() and "noven" not in line_text.lower():
            continue
        parens = re.findall(r"\(([^()]+)\)", line_text)
        if not parens:
            continue
        chosen = clean_intentions_text(parens[-1])
        if not chosen:
            continue
        intentions = split_intentions(chosen)
        if intentions:
            rows.append((urljoin(INTENTIONS_URL, url), title, intentions))
    return rows


def main() -> int:
    local_items = []
    for path in sorted(NOVENAS_DIR.glob("*.json")):
        doc = json.loads(read_text_with_retry(path))
        title = doc.get("title") or doc.get("id") or path.stem
        id_norm = (doc.get("id") or path.stem).replace("_", "-")
        title_norm = re.sub(r"[^a-z0-9-]", "-", (title or "").lower().replace(" ", "-"))
        local_items.append(
            {
                "path": path,
                "id": doc.get("id") or path.stem,
                "title": title,
                "tokens": tokenize(f"{title} {(doc.get('id') or path.stem).replace('_', ' ')}"),
                "slug_keys": {
                    canonical_slugish(id_norm),
                    canonical_slugish(title_norm),
                    canonical_slugish(f"st-{id_norm}"),
                },
            }
        )

    source_by_id: dict[str, dict] = {}

    # Pass 1: dedicated intentions page.
    try:
        intentions_html = fetch(INTENTIONS_URL, timeout=10)
        consolidated = extract_from_intentions_page(intentions_html)
    except Exception:
        consolidated = []

    for url, title, intentions in consolidated:
        item, score = best_match(title, url, local_items)
        if item and score >= 0.70:
            source_by_id[item["id"]] = {"intentions": intentions, "url": url, "title": title, "score": round(score, 3)}

    # Pass 2: table data from novena-prayers page (title in first cell, intentions in last cell).
    try:
        index_html = fetch(INDEX_URL, timeout=10)
        table_rows = extract_intentions_from_index_tables(index_html)
    except Exception:
        table_rows = []

    for url, title, intentions in table_rows:
        item, score = best_match(title, url, local_items)
        if not item or score < 0.70:
            continue
        cur = source_by_id.get(item["id"])
        if cur is None or cur["score"] < score:
            source_by_id[item["id"]] = {
                "intentions": intentions,
                "url": url,
                "title": title,
                "score": round(score, 3),
            }

    # Replace intentions in all novena docs.
    matched = 0
    for item in local_items:
        path = item["path"]
        doc = json.loads(read_text_with_retry(path))
        doc["intentions"] = []
        doc["intentions_es"] = []
        doc["intentions_pl"] = []

        source = source_by_id.get(item["id"])
        if source:
            doc["intentions"] = source["intentions"]
            doc["sources"] = list(dict.fromkeys((doc.get("sources") or []) + [source["url"]]))
            matched += 1

        write_text_with_retry(path, json.dumps(doc, ensure_ascii=False, indent=2) + "\n")

    print(
        f"consolidated_rows={len(consolidated)} table_rows={len(table_rows)} "
        f"matched_novenas={matched} total_local={len(local_items)}"
    )
    for nid, src in list(source_by_id.items())[:20]:
        print(f"sample {nid}: {', '.join(src['intentions'][:3])} :: {src['url']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
