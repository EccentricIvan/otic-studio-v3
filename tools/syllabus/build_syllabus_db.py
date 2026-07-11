#!/usr/bin/env python3
"""Builds assets/db/syllabus.db from one or more curriculum map JSON files.

For each topic node, fetches matching content from Simple English Wikipedia
(unless a local content/<subject>/<class>/<topic-slug>.md override exists),
chunks it into ~300-word segments, and writes it into a SQLite database with
an FTS5 full-text index for retrieval.

Usage:
    python build_syllabus_db.py --maps curriculum_map.json --out ../../assets/db/syllabus.db
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

# Windows consoles default to cp1252, which can't print the unicode
# characters (em-dash, checkmarks) used in the progress/coverage output.
sys.stdout.reconfigure(encoding="utf-8")

WIKI_API = "https://simple.wikipedia.org/w/api.php"
USER_AGENT = "OticStudioSyllabusBuilder/1.0 (offline educational app; contact: n/a)"
RATE_LIMIT_SECONDS = 2.0
MAX_RETRIES = 5
CHUNK_WORDS = 300
CACHE_DIR = Path(__file__).parent / ".cache"

# ── ANSI colors for the coverage report ──────────────────────────────────────
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RESET = "\033[0m"


@dataclass
class TopicNode:
    subject: str
    level: str
    klass: str
    term: int
    theme: str
    topic: str
    keywords: list[str]

    def slug(self) -> str:
        return re.sub(r"[^a-z0-9]+", "-", self.topic.lower()).strip("-")


def load_topics(map_paths: list[Path]) -> list[TopicNode]:
    topics: list[TopicNode] = []
    for path in map_paths:
        data = json.loads(path.read_text(encoding="utf-8"))
        subject = data["subject"]
        level = data["level"]
        for cls in data["classes"]:
            klass = cls["class"]
            for term_block in cls["terms"]:
                term = term_block["term"]
                for t in term_block["topics"]:
                    topics.append(
                        TopicNode(
                            subject=subject,
                            level=level,
                            klass=klass,
                            term=term,
                            theme=t["theme"],
                            topic=t["topic"],
                            keywords=t["keywords"],
                        )
                    )
    return topics


# ── Local content overrides ──────────────────────────────────────────────────

def local_content_path(content_dir: Path, node: TopicNode) -> Path:
    return content_dir / node.subject.lower() / node.klass / f"{node.slug()}.md"


def read_local_content(content_dir: Path, node: TopicNode) -> tuple[str, bool] | None:
    """Returns (markdown_text, exclusive) if a local override exists, else None."""
    path = local_content_path(content_dir, node)
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    exclusive = text.lstrip().startswith("<!-- exclusive -->")
    return text, exclusive


# ── Wikipedia fetch (rate-limited, cached) ──────────────────────────────────

class WikiClient:
    def __init__(self, cache_dir: Path):
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self._last_request = 0.0

    def _throttle(self):
        elapsed = time.time() - self._last_request
        if elapsed < RATE_LIMIT_SECONDS:
            time.sleep(RATE_LIMIT_SECONDS - elapsed)
        self._last_request = time.time()

    def _cache_key(self, url: str) -> Path:
        digest = hashlib.sha256(url.encode()).hexdigest()[:24]
        return self.cache_dir / f"{digest}.json"

    def _get(self, params: dict) -> dict:
        url = f"{WIKI_API}?{urllib.parse.urlencode(params)}"
        cache_path = self._cache_key(url)
        if cache_path.exists():
            return json.loads(cache_path.read_text(encoding="utf-8"))

        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        data = {}
        for attempt in range(MAX_RETRIES):
            self._throttle()
            try:
                with urllib.request.urlopen(req, timeout=15) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                break
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    retry_after = e.headers.get("Retry-After")
                    wait = float(retry_after) if retry_after else (2 ** attempt) * RATE_LIMIT_SECONDS
                    print(f"{YELLOW}  429 rate-limited, waiting {wait:.0f}s (attempt {attempt + 1}/{MAX_RETRIES})...{RESET}")
                    time.sleep(wait)
                    continue
                print(f"{YELLOW}  wiki fetch failed for {url}: {e}{RESET}")
                break
            except Exception as e:
                print(f"{YELLOW}  wiki fetch failed for {url}: {e}{RESET}")
                break
        else:
            print(f"{RED}  gave up after {MAX_RETRIES} retries: {url}{RESET}")

        if data:
            # Only cache real responses — an empty result means every retry
            # failed, and we want a future run to try again, not replay the
            # failure forever.
            cache_path.write_text(json.dumps(data), encoding="utf-8")
        return data

    def search(self, query: str, limit: int = 2) -> list[str]:
        data = self._get(
            {
                "action": "query",
                "list": "search",
                "srsearch": query,
                "srlimit": limit,
                "format": "json",
            }
        )
        return [r["title"] for r in data.get("query", {}).get("search", [])]

    def fetch_extract(self, title: str) -> str:
        data = self._get(
            {
                "action": "query",
                "prop": "extracts",
                "explaintext": 1,
                "titles": title,
                "format": "json",
            }
        )
        pages = data.get("query", {}).get("pages", {})
        for page in pages.values():
            return page.get("extract", "") or ""
        return ""


def clean_wiki_text(text: str) -> str:
    # Strip references/section markers and collapse whitespace. Simple
    # English Wikipedia extracts are already close to plain text via the
    # `explaintext` API param, so this is mostly light cleanup.
    text = re.sub(r"==+\s*References?\s*==+.*", "", text, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r"==+\s*Other websites?\s*==+.*", "", text, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r"==+.*?==+", "\n", text)  # section headers
    text = re.sub(r"\[\d+\]", "", text)  # citation markers
    # MediaWiki math rendering leaks raw LaTeX through explaintext, e.g.
    # "{\displaystyle A=\pi r^{2}}" — strip the wrapper (one level of
    # brace nesting, enough for most formulas) and any stray backslash
    # commands left over.
    text = re.sub(r"\{\\displaystyle(?:[^{}]|\{[^{}]*\})*\}", " ", text)
    text = re.sub(r"\\[a-zA-Z]+", " ", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"\n{2,}", "\n\n", text)
    return text.strip()


def _is_readable_prose(chunk: str) -> bool:
    """Rejects chunks that are mostly broken equation/symbol fragments left
    over from heavily mathematical Wikipedia sections — no amount of markup
    stripping turns "c = 2 τ A = 2 π A {{2 A}}=2{{ A}}}" into something worth
    feeding a tutor prompt. Requires most words to be real (>=2 letter-only
    characters), which prose passes easily and formula soup does not."""
    words = chunk.split()
    if not words:
        return False
    real_words = sum(1 for w in words if re.fullmatch(r"[A-Za-z]{2,}", w))
    return (real_words / len(words)) >= 0.6


def chunk_text(text: str, words_per_chunk: int = CHUNK_WORDS) -> list[str]:
    words = text.split()
    if not words:
        return []
    chunks = []
    for i in range(0, len(words), words_per_chunk):
        chunk = " ".join(words[i : i + words_per_chunk]).strip()
        if len(chunk.split()) >= 20 and _is_readable_prose(chunk):
            chunks.append(chunk)
    return chunks


# ── Database ──────────────────────────────────────────────────────────────────

SCHEMA = """
CREATE TABLE IF NOT EXISTS chunks (
  id INTEGER PRIMARY KEY,
  subject TEXT NOT NULL,
  level TEXT NOT NULL,
  class TEXT NOT NULL,
  term INTEGER NOT NULL,
  theme TEXT NOT NULL,
  topic TEXT NOT NULL,
  chunk_type TEXT NOT NULL,
  source TEXT NOT NULL,
  content TEXT NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
  topic, content,
  content='chunks', content_rowid='id',
  tokenize='porter unicode61'
);

CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
  INSERT INTO chunks_fts(rowid, topic, content) VALUES (new.id, new.topic, new.content);
END;

CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
  INSERT INTO chunks_fts(chunks_fts, rowid, topic, content) VALUES ('delete', old.id, old.topic, old.content);
END;

CREATE TRIGGER IF NOT EXISTS chunks_au AFTER UPDATE ON chunks BEGIN
  INSERT INTO chunks_fts(chunks_fts, rowid, topic, content) VALUES ('delete', old.id, old.topic, old.content);
  INSERT INTO chunks_fts(rowid, topic, content) VALUES (new.id, new.topic, new.content);
END;
"""


def _insert_wiki_titles(conn, node: TopicNode, titles: list[str], wiki: "WikiClient", used_titles: set[str]) -> int:
    """Fetches, cleans, chunks and inserts each title not already used
    elsewhere in the corpus. Returns the number of chunks inserted."""
    chunk_count = 0
    for title in titles:
        if title in used_titles:
            continue
        used_titles.add(title)
        extract = wiki.fetch_extract(title)
        cleaned = clean_wiki_text(extract)
        for chunk in chunk_text(cleaned):
            conn.execute(
                "INSERT INTO chunks (subject, level, class, term, theme, topic, chunk_type, source, content) "
                "VALUES (?, ?, ?, ?, ?, ?, 'content', 'wikipedia', ?)",
                (node.subject, node.level, node.klass, node.term, node.theme, node.topic, chunk),
            )
            chunk_count += 1
    return chunk_count


def build_db(out_path: Path, topics: list[TopicNode], content_dir: Path) -> dict:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()

    conn = sqlite3.connect(out_path)
    conn.executescript(SCHEMA)

    wiki = WikiClient(CACHE_DIR)
    coverage: dict[str, int] = {}
    used_titles: set[str] = set()
    nodes_by_key: dict[str, TopicNode] = {}

    print("Pass 1: combined-keyword search per topic\n")
    for node in topics:
        key = f"{node.klass} T{node.term} — {node.topic}"
        nodes_by_key[key] = node
        chunk_count = 0

        local = read_local_content(content_dir, node)
        if local is not None:
            text, exclusive = local
            body = text.split("-->", 1)[-1] if text.lstrip().startswith("<!--") else text
            for chunk in chunk_text(body):
                conn.execute(
                    "INSERT INTO chunks (subject, level, class, term, theme, topic, chunk_type, source, content) "
                    "VALUES (?, ?, ?, ?, ?, ?, 'content', 'local', ?)",
                    (node.subject, node.level, node.klass, node.term, node.theme, node.topic, chunk),
                )
                chunk_count += 1
        else:
            exclusive = False

        if not exclusive:
            query = " ".join(node.keywords[:3]) or node.topic
            titles = wiki.search(query, limit=2)
            chunk_count += _insert_wiki_titles(conn, node, titles, wiki, used_titles)

        coverage[key] = chunk_count
        status = f"{GREEN}ok{RESET}" if chunk_count else f"{RED}NO CHUNKS{RESET}"
        print(f"  [{status}] {key} ({chunk_count} chunks)")

    # Pass 2: for topics that still have nothing, try each keyword as its
    # own individual search (a joined 3-keyword phrase is often too narrow
    # to match anything), deduping against articles already used elsewhere
    # in the corpus so different topics don't collapse onto the same page.
    gap_keys = [k for k, v in coverage.items() if v == 0]
    if gap_keys:
        print(f"\nPass 2: individual-keyword retry for {len(gap_keys)} zero-chunk topic(s)\n")
        for key in gap_keys:
            node = nodes_by_key[key]
            candidates: list[str] = []
            for keyword in node.keywords:
                results = wiki.search(keyword, limit=1)
                if results and results[0] not in candidates:
                    candidates.append(results[0])
                if len(candidates) >= 3:
                    break

            chunk_count = _insert_wiki_titles(conn, node, candidates, wiki, used_titles)
            coverage[key] = chunk_count
            status = f"{GREEN}ok{RESET}" if chunk_count else f"{RED}NO CHUNKS{RESET}"
            print(f"  [{status}] {key} ({chunk_count} chunks) — tried: {', '.join(node.keywords)}")

    conn.commit()
    conn.execute("VACUUM")
    conn.commit()
    conn.close()
    return coverage


def print_report(coverage: dict[str, int], out_path: Path):
    total_chunks = sum(coverage.values())
    gaps = [k for k, v in coverage.items() if v == 0]

    print("\n" + "=" * 70)
    print("COVERAGE REPORT")
    print("=" * 70)
    print(f"Total topics: {len(coverage)}")
    print(f"Total chunks: {total_chunks}")
    if gaps:
        print(f"\n{RED}Topics with ZERO chunks ({len(gaps)}) — need local content files:{RESET}")
        for g in gaps:
            print(f"  {RED}✗ {g}{RESET}")
    else:
        print(f"\n{GREEN}Every topic has at least one chunk.{RESET}")

    size_bytes = out_path.stat().st_size
    size_mb = size_bytes / (1024 * 1024)
    print(f"\nDB file: {out_path} ({size_mb:.2f} MB)")
    print("=" * 70)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--maps", nargs="+", required=True, help="Curriculum map JSON file(s)")
    parser.add_argument("--out", required=True, help="Output SQLite DB path")
    parser.add_argument(
        "--content-dir",
        default=str(Path(__file__).parent / "content"),
        help="Directory of local markdown overrides (default: ./content)",
    )
    args = parser.parse_args()

    map_paths = [Path(p) for p in args.maps]
    for p in map_paths:
        if not p.exists():
            print(f"Curriculum map not found: {p}", file=sys.stderr)
            sys.exit(1)

    topics = load_topics(map_paths)
    print(f"Loaded {len(topics)} topics from {len(map_paths)} map file(s).\n")

    out_path = Path(args.out)
    content_dir = Path(args.content_dir)
    coverage = build_db(out_path, topics, content_dir)
    print_report(coverage, out_path)


if __name__ == "__main__":
    main()
