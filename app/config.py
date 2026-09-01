import os
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None


APP_DIR = Path(__file__).resolve().parent.parent

# Load local .env when python-dotenv is installed.
# Production platforms such as Render should continue to provide
# credentials through environment variables.
if load_dotenv is not None:
    load_dotenv(APP_DIR / ".env", override=False)
    load_dotenv(APP_DIR / ".env.local", override=False)


def env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


# ---------------------------------------------------------------------------
# Provider credentials
# ---------------------------------------------------------------------------

GROQ_API_KEY = env("GROQ_API_KEY")
CEREBRAS_API_KEY = env("CEREBRAS_API_KEY")
OPENROUTER_API_KEY = env("OPENROUTER_API_KEY")
GEMINI_API_KEY = env("GEMINI_API_KEY")


# ---------------------------------------------------------------------------
# Provider endpoints
# ---------------------------------------------------------------------------

GROQ_URL = env(
    "GROQ_URL",
    "https://api.groq.com/openai/v1/chat/completions",
)

GROQ_MODELS_URL = env(
    "GROQ_MODELS_URL",
    "https://api.groq.com/openai/v1/models",
)

CEREBRAS_URL = env(
    "CEREBRAS_URL",
    "https://api.cerebras.ai/v1/chat/completions",
)

OPENROUTER_URL = env(
    "OPENROUTER_URL",
    "https://openrouter.ai/api/v1/chat/completions",
)


# ---------------------------------------------------------------------------
# Model routing
# ---------------------------------------------------------------------------

# Groq remains the primary provider.
PRIMARY_MODEL = env(
    "PRIMARY_MODEL",
    "groq/openai/gpt-oss-120b",
)

FALLBACK_MODELS = [
    model.strip()
    for model in env(
        "FALLBACK_MODELS",
        "groq/openai/gpt-oss-20b,"
        "cerebras/gpt-oss-120b,"
        "openrouter/openai/gpt-oss-120b",
    ).split(",")
    if model.strip()
]

# Valid OpenRouter IDs must be supplied here.
# Do not use "anthropic/claude-haiku"; that was the invalid ID
# observed in the previous E2E test.
OPENROUTER_MODEL = env(
    "OPENROUTER_MODEL",
    "openai/gpt-oss-120b",
)

OPENROUTER_FALLBACK_MODEL = env(
    "OPENROUTER_FALLBACK_MODEL",
    "openai/gpt-oss-20b",
)


# ---------------------------------------------------------------------------
# Workspace
# ---------------------------------------------------------------------------

WORKSPACE_DIR = env(
    "WORKSPACE_DIR",
    str(APP_DIR / "workspace"),
)

if not WORKSPACE_DIR:
    WORKSPACE_DIR = str(APP_DIR / "workspace")

WORKSPACE_DIR = str(Path(WORKSPACE_DIR).expanduser().resolve())
Path(WORKSPACE_DIR).mkdir(parents=True, exist_ok=True)

PREVIEW_BASE_PORT = int(env("PREVIEW_BASE_PORT", "3000"))


# ---------------------------------------------------------------------------
# WebContainer
# ---------------------------------------------------------------------------

WEBCONTAINER_ENABLED = (
    env("WEBCONTAINER_ENABLED", "false").lower() == "true"
)

WEBCONTAINER_API_URL = env(
    "WEBCONTAINER_API_URL",
    "https://webcontainer.api.stackblitz.com",
)


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

HOST = env("HOST", "0.0.0.0")
PORT = int(env("PORT", "8000"))
