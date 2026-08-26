import json
import re

from .knowledge import load_knowledge
from .providers import chat
from .workspace import (
    execute_command,
    list_files,
    resolve_workspace,
    write_file,
)


SYSTEM_PROMPT = """
You are the production TRAVELER DEV coding agent.

You operate against a real filesystem through a backend execution layer.

Rules:

1. Inspect the existing project before modifying it.
2. Preserve working architecture unless the requested change requires otherwise.
3. Use supplied Markdown knowledge when relevant.
4. Produce complete production-quality files.
5. Never fabricate command execution.
6. Never fabricate tests.
7. Never fabricate preview or deployment URLs.
8. Never use mock implementations.
9. Do not omit required production files.
10. Commands must be necessary for the requested implementation.
11. Do not destroy unrelated project files.
12. Return valid JSON only.

The backend executes writes and commands. The model only proposes them.
"""


def extract_json(text: str):
    fenced = re.search(
        r"```(?:json)?\s*(.*?)\s*```",
        text,
        re.DOTALL | re.IGNORECASE,
    )

    raw = (
        fenced.group(1)
        if fenced
        else text
    ).strip()

    start = raw.find("{")
    end = raw.rfind("}")

    if start < 0 or end <= start:
        raise ValueError(
            "Agent did not return a valid JSON plan."
        )

    try:
        return json.loads(
            raw[start:end + 1]
        )
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"Invalid agent JSON: {exc}"
        ) from exc


def _validate_plan(plan: dict):
    if not isinstance(plan, dict):
        raise ValueError(
            "Agent plan must be an object."
        )

    writes = plan.get("writes", [])
    commands = plan.get("commands", [])

    if not isinstance(writes, list):
        raise ValueError(
            "'writes' must be a list."
        )

    if not isinstance(commands, list):
        raise ValueError(
            "'commands' must be a list."
        )

    for item in writes:
        if not isinstance(item, dict):
            raise ValueError(
                "Every write operation must be an object."
            )

        if not isinstance(
            item.get("path"),
            str,
        ):
            raise ValueError(
                "Write operation requires a path."
            )

        if not isinstance(
            item.get("content"),
            str,
        ):
            raise ValueError(
                "Write operation requires string content."
            )

    for command in commands:
        if not isinstance(command, str):
            raise ValueError(
                "Every command must be a string."
            )


async def run_agent(
    workspace_path: str,
    instruction: str,
    knowledge_names: list[str] | None = None,
):
    root = resolve_workspace(
        workspace_path
    )

    knowledge = load_knowledge(
        knowledge_names
    )

    inventory = list_files(root)

    messages = [
        {
            "role": "system",
            "content": SYSTEM_PROMPT,
        },
        {
            "role": "user",
            "content": (
                "WORKSPACE:\n"
                f"{root}\n\n"
                "CURRENT FILES:\n"
                f"{json.dumps(inventory, indent=2)}\n\n"
                "KNOWLEDGE:\n"
                f"{knowledge}\n\n"
                "USER REQUEST:\n"
                f"{instruction}\n\n"
                "Return JSON only in exactly this structure:\n"
                "{\n"
                '  "summary": "string",\n'
                '  "writes": [\n'
                '    {"path": "relative/path", '
                '"content": "complete file content"}\n'
                "  ],\n"
                '  "commands": ["command"]\n'
                "}"
            ),
        },
    ]

    result = await chat(
        messages,
        max_tokens=30000,
    )

    plan = extract_json(
        result["content"]
    )

    _validate_plan(plan)

    changed = []
    command_results = []

    for item in plan.get("writes", []):
        path = write_file(
            root,
            item["path"],
            item["content"],
        )

        changed.append(path)

    for command in plan.get("commands", []):
        command_result = await execute_command(
            command,
            root,
        )

        command_results.append(
            {
                "command": command,
                **command_result,
            }
        )

        if command_result["returncode"] != 0:
            break

    return {
        "provider": result.get("provider"),
        "provider_model": result["model"],
        "summary": plan.get(
            "summary",
            "",
        ),
        "changed_files": changed,
        "commands": command_results,
    }
