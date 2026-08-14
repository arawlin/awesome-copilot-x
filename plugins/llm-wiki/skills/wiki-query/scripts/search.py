#!/usr/bin/env python3
"""BM25 keyword search over LLM Wiki pages.

Zero-dependency pre-filter for large wikis. When wiki/index.md exceeds
~20K tokens or the wiki has more than ~5,000 pages, run this script to
get ranked candidate pages instead of reading the whole index.

Usage:
    python3 search.py "<query>" [--top-k 10] [--wiki-path "$LLM_WIKI_PATH"]
"""

from __future__ import annotations

import argparse
import math
import os
import re
import sys
from pathlib import Path

_CJK = re.compile(r"[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff]")
_WORD = re.compile(r"[a-z0-9][a-z0-9\-+_.]*", re.IGNORECASE)

# Non-content files inside wiki/ that must never rank as answers.
_EXCLUDE = {"index.md", "log.md", "activity.md"}


def _cjk_bigrams(text: str) -> list[str]:
    """Emit overlapping character bigrams for CJK runs (works without a segmenter)."""
    run = "".join(_CJK.findall(text))
    return [run[i : i + 2] for i in range(len(run) - 1)]


def tokenize(text: str) -> list[str]:
    """Split into lowercase word tokens; CJK runs become character bigrams."""
    tokens: list[str] = []
    pos = 0
    for match in _WORD.finditer(text):
        tokens.extend(_cjk_bigrams(text[pos : match.start()]))
        tokens.append(match.group().lower())
        pos = match.end()
    tokens.extend(_cjk_bigrams(text[pos:]))
    return tokens


class BM25:
    """Minimal Okapi BM25 with standard k1/b defaults."""

    def __init__(self, k1: float = 1.5, b: float = 0.75) -> None:
        self.k1 = k1
        self.b = b
        self.docs: list[list[str]] = []
        self.avgdl = 0.0
        self.df: dict[str, int] = {}

    def index(self, docs: list[list[str]]) -> None:
        self.docs = docs
        self.avgdl = sum(len(d) for d in docs) / max(len(docs), 1)
        for doc in docs:
            for term in set(doc):
                self.df[term] = self.df.get(term, 0) + 1

    def score(self, query: list[str]) -> list[float]:
        n = len(self.docs)
        scores = [0.0] * n
        for term in set(query):
            df = self.df.get(term)
            if not df:
                continue
            idf = math.log(1 + (n - df + 0.5) / (df + 0.5))
            for i, doc in enumerate(self.docs):
                tf = doc.count(term)
                if not tf:
                    continue
                norm = 1 - self.b + self.b * (len(doc) / self.avgdl)
                scores[i] += idf * (tf * (self.k1 + 1)) / (tf + self.k1 * norm)
        return scores


def main() -> int:
    parser = argparse.ArgumentParser(description="BM25 search over LLM Wiki pages")
    parser.add_argument("query", help="search terms (quote if they contain spaces)")
    parser.add_argument("--top-k", type=int, default=10, help="number of results (default: 10)")
    parser.add_argument("--wiki-path", default=None, help="wiki repo root (default: $LLM_WIKI_PATH)")
    args = parser.parse_args()

    base = Path(args.wiki_path or os.environ.get("LLM_WIKI_PATH") or ".")
    wiki = base / "wiki" if (base / "wiki").is_dir() else base

    pages = [p for p in sorted(wiki.rglob("*.md")) if p.name not in _EXCLUDE]
    if not pages:
        print(f"No pages found under {wiki}", file=sys.stderr)
        return 1

    model = BM25()
    model.index([tokenize(p.read_text(encoding="utf-8", errors="ignore")) for p in pages])
    scores = model.score(tokenize(args.query))

    ranked = sorted(zip(pages, scores), key=lambda item: item[1], reverse=True)
    printed = 0
    for page, score in ranked[: args.top_k]:
        if score <= 0:
            break
        rel = page.relative_to(wiki).with_suffix("").as_posix()
        print(f"{score:8.3f}  [[{rel}]]  {page}")
        printed += 1
    if not printed:
        print("No matches. Try different or broader terms.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
