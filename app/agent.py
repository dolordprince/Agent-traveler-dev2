from __future__ import annotations

import json
import re
from typing import Any

from .knowledge import (
    knowledge_context,
    list_knowledge,
    load_knowledge,
    read_knowledge,
    search_knowledge,
)
from .providers import chat
from .workspace import (
    execute_command,
    list_files,
    read_file,
    resolve_workspace,
    write_file,
)


SYSTEM_PROMPT = """
You are the production TRAVELER DEV autonomous software engineering agent.

You build COMPLETE, REAL, PRODUCTION-QUALITY applications and websites.

You operate against a real filesystem.

CORE RULES:

1. Inspect the existing repository before changing anything.
2. Never destroy unrelated working functionality.
3. Use the Markdown knowledge base as technical source material.
4. Search the knowledge base when implementing frameworks, SDKs, APIs,
   architecture, integrations, UI patterns, deployment procedures, or
   other subjects covered by the documents.
5. Read the relevant knowledge document when search results are insufficient.
6. Do not pretend that model training knowledge is equivalent to project
   documentation.
7. Do not fabricate APIs, SDK methods, configuration contracts, credentials,
   dependencies, commands, test results, URLs, or deployment results.
8. Create complete files, not fragments.
9. Do not create mock APIs, fake providers, fake databases, fake deployments,
   fake test results, placeholder production integrations, or simulated
   success states.
10. Use real dependencies and real APIs where the project requires them.
11. Preserve existing production architecture unless the requested task
    requires an architectural change.
12. Inspect package manifests and existing source before adding dependencies.
13. Install dependencies when required.
14. Run real validation after modifications.
15. Build the application before declaring it complete.
16. If validation fails, inspect the failure and repair the implementation.
17. Repeat the repair/validation cycle until the requested implementation
    is actually working or a genuine external blocker prevents completion.
18. Never report success merely because files were written.
19. Never expose secrets.
20. Never write API keys, tokens, passwords, private keys, or credentials
    into source files.
21. Never commit secrets.
22. Generated web applications are deployed ONLY through the TRAVELER DEV
    Surge deployment pipeline.
23. Vercel is NOT a generated-project deployment provider.
24. Vercel AI SDK / AI Gateway may be used for the coding-agent runtime only.
25. Never claim a Surge deployment succeeded until the actual deployment
    command and live URL have been verified.
26. Return the actual deployment URL when one exists.
27. Generate downloadable project artifacts from the real generated project.
28. For mobile applications, generate the real requested application artifact
    through the available production build pipeline.
29. Do not stop after producing a plan. Execute the implementation.
30. Do not omit required files merely to reduce output size.

The Markdown knowledge base is part of the production engineering system.
Use it actively.
"""


def extract_json(text: str) -> dict[str, Any]:
    fenced = re.search(
        r"```(?:json)?\s*(.*?)\s*```",
        text,
        re.DOTALL | re.IGNORECASE,
    )

    raw = fenced.group(1) if fenced else text
    raw = raw.strip()

    start = raw.find("{")
    end = raw.rfind("}")

    if start < 0 or end <= start:
        raise ValueError("Agent did not return a valid JSON object.")

    try:
        value = json.loads(raw[start : end + 1])
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid agent JSON: {exc}") from exc

    if not isinstance(value, dict):
        raise ValueError("Agent response must be a JSON object.")

    return value


def _validate_plan(plan: dict[str, Any]) -> None:
    writes = plan.get("writes", [])
    commands = plan.get("commands", [])

    if not isinstance(writes, list):
        raise ValueError("'writes' must be a list.")

    if not isinstance(commands, list):
        raise ValueError("'commands' must be a list.")

    for item in writes:
        if not isinstance(item, dict):
            raise ValueError("Every write operation must be an object.")

        if not isinstance(item.get("path"), str):
            raise ValueError("Every write requires a path.")

        if not isinstance(item.get("content"), str):
            raise ValueError("Every write requires complete file content.")

    for command in commands:
        if not isinstance(command, str):
            raise ValueError("Every command must be a string.")


async def _ask_agent(
    *,
    workspace: str,
    instruction: str,
    inventory: list[dict],
    knowledge: str,
    previous_failures: str = "",
) -> dict[str, Any]:

    prompt = f"""
WORKSPACE:
{workspace}

CURRENT FILE INVENTORY:
{json.dumps(inventory, indent=2)}

RELEVANT MARKDOWN KNOWLEDGE:
{knowledge}

PREVIOUS VALIDATION FAILURES:
{previous_failures or "None"}

USER REQUEST:
{instruction}

You are responsible for implementing the request, not merely describing it.

Return JSON only:

{{
  "summary": "what was implemented",
  "writes": [
    {{
      "path": "relative/path",
      "content": "COMPLETE file content"
    }}
  ],
  "commands": [
    "real command to execute"
  ]
}}

The files must be complete production files.
Do not use placeholders.
"""


    result = await chat(
        [
            {
                "role": "system",
                "content": SYSTEM_PROMPT,
            },
            {
                "role": "user",
                "content": prompt,
            },
        ],
        max_tokens=30000,
    )

    return extract_json(result["content"])


async def run_agent(
    workspace_path: str,
    instruction: str,
    knowledge_names: list[str] | None = None,
):
    root = resolve_workspace(workspace_path)

    inventory = list_files(root)

    requested_knowledge = load_knowledge(knowledge_names)

    relevant_knowledge = knowledge_context(instruction)

    knowledge = (
        relevant_knowledge
        if relevant_knowledge.strip()
        else requested_knowledge
    )

    previous_failures = ""

    changed: list[str] = []
    command_results: list[dict] = []

    max_iterations = 6

    for iteration in range(1, max_iterations + 1):
        plan = await _ask_agent(
            workspace=str(root),
            instruction=instruction,
            inventory=inventory,
            knowledge=knowledge,
            previous_failures=previous_failures,
        )

        _validate_plan(plan)

        for item in plan.get("writes", []):
            path = write_file(
                root,
                item["path"],
                item["content"],
            )

            if path not in changed:
                changed.append(path)

        iteration_failures: list[str] = []

        for command in plan.get("commands", []):
            result = await execute_command(
                command,
                root,
            )

            command_results.append(
                {
                    "iteration": iteration,
                    "command": command,
                    **result,
                }
            )

            if result["returncode"] != 0:
                iteration_failures.append(
                    f"$ {command}\n{result['output']}"
                )
                break

        inventory = list_files(root)

        if not iteration_failures:
            return {
                "status": "completed",
                "provider": plan.get("provider"),
                "summary": plan.get("summary", ""),
                "changed_files": changed,
                "commands": command_results,
                "iterations": iteration,
            }

        previous_failures = "\n\n".join(iteration_failures)

        if iteration == max_iterations:
            return {
                "status": "failed_validation",
                "summary": plan.get("summary", ""),
                "changed_files": changed,
                "commands": command_results,
                "iterations": iteration,
                "validation_error": previous_failures,
            }

    raise RuntimeError("Agent execution ended unexpectedly.")


__all__ = [
    "run_agent",
    "list_knowledge",
    "read_knowledge",
    "search_knowledge",
]
