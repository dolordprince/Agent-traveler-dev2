import os

# API Keys
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
CEREBRAS_API_KEY = os.getenv("CEREBRAS_API_KEY", "")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

# URLs
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODELS_URL = "https://api.groq.com/openai/v1/models"
CEREBRAS_URL = "https://api.cerebras.ai/v1/chat/completions"
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Workspace + Preview
WORKSPACE_DIR = "/root/Agent-traveler-dev2/workspace"
PREVIEW_BASE_PORT = 3000

# Primary model (confirmed working)
PRIMARY_MODEL = "groq/openai/gpt-oss-120b"

# Fallback chain — ordered list of "provider/model" strings
FALLBACK_MODELS = [
    "groq/openai/gpt-oss-120b",
    "groq/openai/gpt-oss-20b",
]

# OpenRouter models
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "anthropic/claude-haiku")
OPENROUTER_FALLBACK_MODEL = os.getenv("OPENROUTER_FALLBACK_MODEL", "mistralai/mistral-7b-instruct")

# StackBlitz WebContainer
WEBCONTAINER_ENABLED = os.getenv("WEBCONTAINER_ENABLED", "false").lower() == "true"

# Server config
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))

os.makedirs(WORKSPACE_DIR, exist_ok=True)
