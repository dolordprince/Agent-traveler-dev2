from pathlib import Path
from .config import KNOWLEDGE_DIR

def load_knowledge(names: list[str] | None = None) -> str:
    names = names or []

    files = []

    if names:
        for name in names:
            path = KNOWLEDGE_DIR / Path(name).name
            if path.is_file() and path.suffix.lower() == ".md":
                files.append(path)
    else:
        files = sorted(KNOWLEDGE_DIR.glob("*.md"))

    sections = []

    for path in files:
        sections.append(
            f"\n===== KNOWLEDGE: {path.name} =====\n"
            f"{path.read_text(encoding='utf-8')}\n"
        )

    return "\n".join(sections)
