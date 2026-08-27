import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

KNOWLEDGE_DIR = BASE_DIR / "knowledge"
WORKSPACE_DIR = BASE_DIR / "workspace"
GENERATED_DIR = BASE_DIR / "generated_projects"
ARTIFACT_DIR = BASE_DIR / "artifacts"
PREVIEW_DIR = BASE_DIR / "previews"
LOG_DIR = BASE_DIR / "logs"
JOB_DIR = BASE_DIR / "jobs"

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "7860"))

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "").strip()
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "").strip()
CEREBRAS_API_KEY = os.getenv("CEREBRAS_API_KEY", "").strip()

GATEWAY_API_KEY = os.getenv("GATEWAY_API_KEY", "bypass").strip()

PRIMARY_MODEL = os.getenv(
    "PRIMARY_MODEL",
    "groq/llama-3.3-70b-versatile",
).strip()

FALLBACK_MODELS = [
    value.strip()
    for value in os.getenv(
        "FALLBACK_MODELS",
        "cerebras/llama-3.3-70b,minimax/minimax-m3:free",
    ).split(",")
    if value.strip()
]

OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "minimax/minimax-m3:free").strip()
OPENROUTER_FALLBACK_MODEL = os.getenv(
    "OPENROUTER_FALLBACK_MODEL",
    "openrouter/free",
).strip()

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
CEREBRAS_URL = "https://api.cerebras.ai/v1/chat/completions"
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

SURGE_TOKEN = os.getenv("SURGE_TOKEN", "").strip()
SURGE_DOMAIN_PREFIX = os.getenv(
    "SURGE_DOMAIN_PREFIX",
    "traveler-dev",
).strip()

MAX_COMMAND_SECONDS = int(os.getenv("MAX_COMMAND_SECONDS", "900"))
MAX_OUTPUT_BYTES = int(os.getenv("MAX_OUTPUT_BYTES", str(4 * 1024 * 1024)))
PREVIEW_START_TIMEOUT = int(os.getenv("PREVIEW_START_TIMEOUT", "30"))
PREVIEW_SHUTDOWN_TIMEOUT = int(os.getenv("PREVIEW_SHUTDOWN_TIMEOUT", "10"))

for directory in (
    KNOWLEDGE_DIR,
    WORKSPACE_DIR,
    GENERATED_DIR,
    ARTIFACT_DIR,
    PREVIEW_DIR,
    LOG_DIR,
    JOB_DIR,
):
    directory.mkdir(parents=True, exist_ok=True)

# ── Vercel AI Gateway ─────────────────────────────────────────────────────────
AI_GATEWAY_API_KEY = os.getenv("AI_GATEWAY_API_KEY", "").strip()
VERCEL_GATEWAY_URL = os.getenv(
    "VERCEL_GATEWAY_URL",
    "https://ai-gateway.vercel.sh/v1/chat/completions",
).strip()
VERCEL_GATEWAY_MODEL = os.getenv(
    "VERCEL_GATEWAY_MODEL",
    "anthropic/claude-sonnet-4-6",
).strip()

# ── Kilo AI Gateway ───────────────────────────────────────────────────────────
KILO_API_KEY = os.getenv("KILO_API_KEY", "").strip()
KILO_GATEWAY_URL = os.getenv(
    "KILO_GATEWAY_URL",
    "https://api.kilo.ai/api/gateway/chat/completions",
).strip()
KILO_MODEL = os.getenv("KILO_MODEL", "anthropic/claude-sonnet-4-6").strip()

# ── Google Gemini (free tier available) ──────────────────────────────────────
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.6-flash").strip()
