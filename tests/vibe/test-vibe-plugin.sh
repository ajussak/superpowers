#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Vibe plugin wiring tests"

python3 - "$REPO_ROOT" <<'PY'
import json
import re
import sys
import tomllib
from pathlib import Path

root = Path(sys.argv[1])


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


manifest = json.loads((root / "plugin.json").read_text(encoding="utf-8"))
check(
    manifest.get("$schema")
    == "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
    "plugin.json $schema must be the Agent Plugins 1.0 schema URL",
)
check(manifest.get("name") == "superpowers", "plugin name")
package = json.loads((root / "package.json").read_text(encoding="utf-8"))
check(
    manifest.get("version") == package.get("version"),
    "plugin.json version must match package.json version",
)
ext = manifest.get("extensions", {}).get("ai.mistral.vibe", {})
check(ext.get("schemaVersion") == 1, "ai.mistral.vibe extension schemaVersion must be 1")
check(
    isinstance(ext.get("displayName"), str) and ext["displayName"].strip(),
    "ai.mistral.vibe extension needs a displayName",
)

hooks_path = root / "ai.mistral.vibe" / "hooks.toml"
hooks_doc = tomllib.loads(hooks_path.read_text(encoding="utf-8"))
hooks = hooks_doc.get("hooks", [])
check(len(hooks) == 1, "hooks.toml must declare exactly one hook")
hook = hooks[0]
check(hook.get("type") == "session_start", "plugin hook type must be session_start")
check(isinstance(hook.get("name"), str) and hook["name"].strip(), "hook needs a name")
command = hook.get("command", "")
for needle in ("$PLUGIN_ROOT", "run-hook.cmd", "session-start"):
    check(needle in command, f"hook command must reference {needle!r}")

version_config = json.loads((root / ".version-bump.json").read_text(encoding="utf-8"))
check(
    any(
        entry.get("path") == "plugin.json" and entry.get("field") == "version"
        for entry in version_config.get("files", [])
        if isinstance(entry, dict)
    ),
    ".version-bump.json must update plugin.json version",
)

skill_md = (root / "skills" / "using-superpowers" / "SKILL.md").read_text(encoding="utf-8")
check(
    "references/vibe-tools.md" in skill_md,
    "using-superpowers SKILL.md must list references/vibe-tools.md in Platform Adaptation",
)
check(
    (root / "skills" / "using-superpowers" / "references" / "vibe-tools.md").is_file(),
    "references/vibe-tools.md must exist",
)

for skill_dir in sorted((root / "skills").iterdir()):
    if not skill_dir.is_dir():
        continue
    frontmatter_name = re.search(
        r"^name:\s*(\S+)", (skill_dir / "SKILL.md").read_text(encoding="utf-8"), re.M
    )
    check(
        frontmatter_name is not None and frontmatter_name.group(1) == skill_dir.name,
        f"Vibe requires frontmatter name to match the directory: {skill_dir.name}",
    )

print("PASS: plugin.json, ai.mistral.vibe/hooks.toml, version-bump, and skill wiring")
PY

TEST_ROOT="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT
mkdir -p "$TEST_ROOT/home"

check_hook_shape() {
    local description="$1"
    local output="$2"
    printf '%s' "$output" >"$TEST_ROOT/hook-output.json"
    python3 - "$description" "$TEST_ROOT/hook-output.json" <<'PY'
import json
import sys

description = sys.argv[1]
with open(sys.argv[2], encoding="utf-8") as handle:
    payload = json.load(handle)
assert "hookSpecificOutput" not in payload, f"{description}: unexpected hookSpecificOutput"
assert "additional_context" not in payload, f"{description}: unexpected top-level additional_context"
assert "additionalContext" not in payload, f"{description}: unexpected top-level additionalContext"
hook_output = payload.get("hook_specific_output")
assert isinstance(hook_output, dict), f"{description}: missing hook_specific_output object"
context = hook_output.get("additional_context")
assert isinstance(context, str) and context.strip(), f"{description}: empty additional_context"
assert "EXTREMELY_IMPORTANT" in context, f"{description}: bootstrap wrapper missing"
assert "You have superpowers." in context, f"{description}: bootstrap text missing"
print(f"PASS: {description}")
PY
}

vibe_direct="$(env -i PATH="${PATH:-}" HOME="$TEST_ROOT/home" PLUGIN_ROOT="$REPO_ROOT" \
    bash "$REPO_ROOT/hooks/session-start")"
check_hook_shape "session-start with PLUGIN_ROOT emits Vibe hook_specific_output.additional_context" \
    "$vibe_direct"

vibe_wrapper="$(env -i PATH="${PATH:-}" HOME="$TEST_ROOT/home" PLUGIN_ROOT="$REPO_ROOT" \
    bash "$REPO_ROOT/hooks/run-hook.cmd" session-start)"
check_hook_shape "run-hook.cmd with PLUGIN_ROOT dispatches to the Vibe shape" \
    "$vibe_wrapper"

echo "All Vibe plugin tests passed"
