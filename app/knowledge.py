from __future__ import annotations

import re
from pathlib import Path
from typing import Iterable

from .config import KNOWLEDGE_DIR


def _safe_name(name: str) -> str:
    return Path(name).name


def list_knowledge() -> list[dict]:
    KNOWLEDGE_DIR.mkdir(parents=True, exist_ok=True)

    result: list[dict] = []

    for path in sorted(KNOWLEDGE_DIR.glob("*.md")):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue

        result.append(
            {
                "name": path.name,
                "characters": len(text),
                "path": str(path),
            }
        )

    return result


def _load_file(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def load_knowledge(names: list[str] | None = None) -> str:
    KNOWLEDGE_DIR.mkdir(parents=True, exist_ok=True)

    if names:
        paths = []

        for name in names:
            path = KNOWLEDGE_DIR / _safe_name(name)

            if path.is_file() and path.suffix.lower() == ".md":
                paths.append(path)
    else:
        paths = sorted(KNOWLEDGE_DIR.glob("*.md"))

    sections: list[str] = []

    for path in paths:
        sections.append(
            f"\n===== KNOWLEDGE: {path.name} =====\n"
            f"{_load_file(path)}\n"
        )

    return "\n".join(sections)


def read_knowledge(name: str) -> str:
    path = KNOWLEDGE_DIR / _safe_name(name)

    if not path.is_file():
        raise FileNotFoundError(f"Knowledge document not found: {name}")

    if path.suffix.lower() != ".md":
        raise ValueError("Only Markdown knowledge documents are supported.")

    return _load_file(path)


def _normalise(value: str) -> str:
    return re.sub(r"\s+", " ", value.lower()).strip()


def _terms(query: str) -> list[str]:
    return [
        token
        for token in re.findall(r"[a-zA-Z0-9_./:@+-]{2,}", query.lower())
        if token not in {
            "the",
            "and",
            "for",
            "with",
            "from",
            "that",
            "this",
            "into",
            "using",
            "use",
            "how",
            "what",
            "build",
        }
    ]


def search_knowledge(
    query: str,
    *,
    max_results: int = 8,
    max_chars_per_result: int = 12000,
) -> list[dict]:
    KNOWLEDGE_DIR.mkdir(parents=True, exist_ok=True)

    query = _normalise(query)

    if not query:
        return []

    terms = _terms(query)
    results: list[dict] = []

    for path in sorted(KNOWLEDGE_DIR.glob("*.md")):
        try:
            text = _load_file(path)
        except OSError:
            continue

        normalised = _normalise(text)

        score = 0

        if query in normalised:
            score += 100

        for term in terms:
            score += normalised.count(term)

        if score <= 0:
            continue

        lines = text.splitlines()

        matched_chunks: list[str] = []

        for index, line in enumerate(lines):
            lower = line.lower()

            if query in lower or any(term in lower for term in terms):
                start = max(0, index - 5)
                end = min(len(lines), index + 16)

                chunk = "\n".join(lines[start:end])

                if chunk not in matched_chunks:
                    matched_chunks.append(chunk)

                if sum(len(x) for x in matched_chunks) >= max_chars_per_result:
                    break

        excerpt = "\n\n---\n\n".join(matched_chunks)

        results.append(
            {
                "name": path.name,
                "score": score,
                "excerpt": excerpt[:max_chars_per_result],
            }
        )

    results.sort(
        key=lambda item: (
            -item["score"],
            item["name"],
        )
    )

    return results[:max_results]


def knowledge_context(
    query: str,
    *,
    max_results: int = 6,
    max_chars: int = 50000,
) -> str:
    results = search_knowledge(
        query,
        max_results=max_results,
    )

    if not results:
        return ""

    chunks: list[str] = []

    for result in results:
        chunks.append(
            f"===== KNOWLEDGE RESULT: {result['name']} =====\n"
            f"{result['excerpt']}"
        )

    return "\n\n".join(chunks)[:max_chars]
