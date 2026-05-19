#!/usr/bin/env python3
"""
Guard Unsafe Code — PreToolUse hook for Edit/Write/MultiEdit/NotebookEdit.

Detects 10 dangerous code patterns being written by dev-squad agents and
warns (advisory mode) or blocks (strict mode). Patterns ported from
security-guidance plugin.

Modes:
  default        warn once per session per (file × pattern), log to
                 .dev-squad/security-warnings.log, allow tool to proceed
  strict         set DEV_SQUAD_STRICT_SECURITY=1 → exit 2 (block tool)

Patterns covered:
  - eval / new Function / pickle / os.system          (code injection)
  - subprocess.run/Popen with shell=True              (shell injection, Python)
  - child_process.exec / execSync                     (shell injection, JS)
  - dangerouslySetInnerHTML / .innerHTML= / document.write   (XSS)
  - GitHub Actions workflow ${{ untrusted }} in run:  (CI injection)
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path


SECURITY_PATTERNS = [
    {
        "name": "github_actions_injection",
        "path_check": lambda path: ".github/workflows/" in path
        and (path.endswith(".yml") or path.endswith(".yaml")),
        "content_check": lambda content: any(
            f"${{{{ {expr}" in content
            for expr in (
                "github.event.issue.title",
                "github.event.issue.body",
                "github.event.pull_request.title",
                "github.event.pull_request.body",
                "github.event.comment.body",
                "github.event.review.body",
                "github.event.head_commit.message",
                "github.head_ref",
            )
        ),
        "reminder": (
            "GitHub Actions workflow injection risk. Untrusted input "
            "(issue title, PR body, commit message) used directly in "
            "${{ ... }} inside `run:` is a known attack vector. Use "
            "env: + quoted shell var instead.\n"
            "Reference: https://github.blog/security/vulnerability-research/"
            "how-to-catch-github-actions-workflow-injections-before-attackers-do/"
        ),
    },
    {
        "name": "child_process_exec",
        "substrings": ["child_process.exec(", "exec(`", "execSync("],
        "reminder": (
            "child_process.exec / execSync with template literals = command "
            "injection risk. Use execFile (no shell), or sanitize/escape input. "
            "Only use exec() if you truly need shell features and input is "
            "guaranteed safe."
        ),
    },
    {
        "name": "new_function_injection",
        "substrings": ["new Function("],
        "reminder": (
            "new Function() with dynamic strings = code injection. Consider "
            "JSON.parse for data, or alternative design that doesn't evaluate "
            "arbitrary code."
        ),
    },
    {
        "name": "eval_injection",
        "substrings": ["eval("],
        "reminder": (
            "eval() executes arbitrary code = major security risk. Use "
            "JSON.parse() for data parsing or alternative patterns. Only use "
            "eval() if you truly need arbitrary code evaluation."
        ),
    },
    {
        "name": "dangerously_set_html",
        "substrings": ["dangerouslySetInnerHTML"],
        "reminder": (
            "dangerouslySetInnerHTML can lead to XSS if used with untrusted "
            "content. Sanitize via DOMPurify, or use safe alternatives like "
            "{children} text rendering."
        ),
    },
    {
        "name": "document_write_xss",
        "substrings": ["document.write("],
        "reminder": (
            "document.write() = XSS-prone + perf-bad. Use createElement / "
            "appendChild or modern DOM APIs."
        ),
    },
    {
        "name": "innerhtml_xss",
        "substrings": [".innerHTML =", ".innerHTML="],
        "reminder": (
            "Setting .innerHTML with untrusted content = XSS risk. Use "
            "textContent for plain text, or sanitize via DOMPurify before "
            "innerHTML."
        ),
    },
    {
        "name": "pickle_deserialization",
        "substrings": ["import pickle", "pickle.load(", "pickle.loads("],
        "reminder": (
            "pickle on untrusted data = arbitrary code execution. Use JSON, "
            "msgpack, or Pydantic for serialization. Only use pickle for "
            "trusted internal data."
        ),
    },
    {
        "name": "os_system_injection",
        "substrings": ["os.system(", "from os import system"],
        "reminder": (
            "os.system() with user input = shell injection. Use subprocess.run "
            "with list args (no shell=True), or shlex.quote for escaping."
        ),
    },
    {
        "name": "subprocess_shell_true",
        "substrings": ["shell=True"],
        "reminder": (
            "subprocess.run(..., shell=True) / Popen(..., shell=True) with "
            "untrusted input = shell injection. Pass args as a list (default "
            "shell=False), or use shlex.quote() if a shell is unavoidable."
        ),
    },
]


def state_dir() -> Path:
    """Per-session state lives under ~/.dev-squad/security/."""
    d = Path.home() / ".dev-squad" / "security"
    d.mkdir(parents=True, exist_ok=True)
    return d


def state_file(session_id: str) -> Path:
    return state_dir() / f"warned-{session_id}.json"


def load_warned(session_id: str) -> set:
    p = state_file(session_id)
    if not p.exists():
        return set()
    try:
        return set(json.loads(p.read_text()))
    except (json.JSONDecodeError, OSError):
        return set()


def save_warned(session_id: str, warned: set) -> None:
    try:
        state_file(session_id).write_text(json.dumps(sorted(warned)))
    except OSError:
        pass


def project_log_append(file_path: str, pattern_name: str, reminder: str) -> None:
    """Append warning to .dev-squad/security-warnings.log in the project root."""
    try:
        proj_root = Path.cwd()
        # Walk up to find .dev-squad or git root
        for _ in range(8):
            if (proj_root / ".dev-squad").exists() or (proj_root / ".git").exists():
                break
            if proj_root.parent == proj_root:
                break
            proj_root = proj_root.parent

        log_dir = proj_root / ".dev-squad"
        log_dir.mkdir(exist_ok=True)
        log_path = log_dir / "security-warnings.log"
        timestamp = datetime.now().isoformat(timespec="seconds")
        with log_path.open("a") as f:
            f.write(
                f"[{timestamp}] {pattern_name}\n  file: {file_path}\n  why: {reminder}\n\n"
            )
    except OSError:
        pass


def extract_content(tool_name: str, tool_input: dict) -> str:
    if tool_name == "Write":
        return tool_input.get("content", "") or ""
    if tool_name == "Edit":
        return tool_input.get("new_string", "") or ""
    if tool_name == "MultiEdit":
        edits = tool_input.get("edits", []) or []
        return "\n".join((e.get("new_string", "") or "") for e in edits)
    if tool_name == "NotebookEdit":
        return tool_input.get("new_source", "") or ""
    return ""


def check(file_path: str, content: str):
    norm = file_path.lstrip("/") if file_path else ""
    for pat in SECURITY_PATTERNS:
        if "path_check" in pat and norm and pat["path_check"](norm):
            if "content_check" in pat:
                if pat["content_check"](content):
                    return pat["name"], pat["reminder"]
            else:
                return pat["name"], pat["reminder"]
        if "substrings" in pat and content:
            if any(s in content for s in pat["substrings"]):
                return pat["name"], pat["reminder"]
    return None, None


def main() -> int:
    if os.environ.get("DEV_SQUAD_DISABLE_UNSAFE_CODE_GUARD") == "1":
        return 0

    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw else {}
    except json.JSONDecodeError:
        return 0  # don't block on parse failure

    tool_name = data.get("tool_name", "")
    if tool_name not in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        return 0

    tool_input = data.get("tool_input", {}) or {}
    # NotebookEdit uses notebook_path instead of file_path
    file_path = (
        tool_input.get("file_path", "") or tool_input.get("notebook_path", "") or ""
    )
    if not file_path:
        return 0

    # Allow-list: don't warn on the dev-squad plugin itself or test fixtures
    allow_substrings = (
        "/dev-squad-plugin/",
        "/__tests__/",
        "/tests/fixtures/",
        "/test/fixtures/",
        ".test.",
        ".spec.",
    )
    if any(s in file_path for s in allow_substrings):
        return 0

    content = extract_content(tool_name, tool_input)
    pattern_name, reminder = check(file_path, content)
    if not pattern_name:
        return 0

    session_id = data.get("session_id", "default")
    warned = load_warned(session_id)
    key = f"{file_path}::{pattern_name}"

    strict = os.environ.get("DEV_SQUAD_STRICT_SECURITY") == "1"

    if key in warned and not strict:
        return 0  # already warned this session, advisory mode lets it pass

    warned.add(key)
    save_warned(session_id, warned)
    project_log_append(file_path, pattern_name, reminder)

    print(f"[dev-squad security] {pattern_name} in {file_path}", file=sys.stderr)
    print(reminder, file=sys.stderr)

    if strict:
        print(
            "Strict mode (DEV_SQUAD_STRICT_SECURITY=1) — blocking edit. "
            "Unset to switch to advisory.",
            file=sys.stderr,
        )
        return 2  # block

    print(
        "Advisory mode — proceeding. Set DEV_SQUAD_STRICT_SECURITY=1 to block, "
        "or DEV_SQUAD_DISABLE_UNSAFE_CODE_GUARD=1 to disable entirely.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
