# Superpowers for Mistral Vibe Code

Complete guide for using Superpowers with [Mistral Vibe Code](https://github.com/mistralai/mistral-vibe) (the `vibe` CLI).

## Installation

Vibe loads plugins in the [Agent Plugins 1.0](https://agent-plugins.org) format from `~/.vibe/plugins/<name>/` (every session) and `./.vibe/plugins/<name>/` (trusted project folders). This repository is itself the plugin: the root `plugin.json` declares the `ai.mistral.vibe` extension, and Vibe loads the shared `skills/` directory plus `ai.mistral.vibe/hooks.toml` from it.

Install as a user plugin, available in every project:

```bash
git clone https://github.com/obra/superpowers.git ~/.vibe/plugins/superpowers
```

Or as a project plugin, loaded only when the folder is trusted:

```bash
mkdir -p .vibe/plugins
git clone https://github.com/obra/superpowers.git .vibe/plugins/superpowers
```

Start a new session, or run `/reload-plugins` in a running one, then confirm with `/plugins` that `superpowers` is listed. Skills appear as `superpowers:<skill-name>` (slash command `/superpowers:<skill-name>`).

## How it works

1. `plugin.json` (Agent Plugins 1.0, `$schema` 1.0.0) makes Vibe load the repository root as a plugin. Its presence takes precedence over the repo's other harness markers (`.claude-plugin/`, `.codex-plugin/`, `.kimi-plugin/`), which Vibe would otherwise refuse to load because more than one foreign format is present.
2. `ai.mistral.vibe/hooks.toml` declares a `session_start` hook that runs `"$PLUGIN_ROOT/hooks/run-hook.cmd" session-start`. Vibe runs plugin hooks in the session's pinned copy of the plugin with `PLUGIN_ROOT` set.
3. `hooks/session-start` detects `PLUGIN_ROOT` and prints `{"hook_specific_output": {"additional_context": ...}}` containing the full `using-superpowers` skill wrapped in `<EXTREMELY_IMPORTANT>`. Vibe appends that text to the model's context at the start of every session — startup, resume, `/clear`, and fork all re-inject.
4. The per-harness tool mapping lives in `skills/using-superpowers/references/vibe-tools.md`, listed from the `Platform Adaptation` section of `using-superpowers`.

There are no copied skills, no symlinks, no edits to your `~/.vibe/config.toml` or `hooks.toml`, and no runtime dependencies.

## Tool mapping

Skills describe actions instead of hard-coding one runtime's tool names. On Vibe Code these resolve to:

- "Read a file" -> `read_file`; "create a new file" -> `write_file`; "edit a file" -> `edit`
- "Run a shell command" -> `bash`; "search file contents" -> `grep`; "find files by path or pattern" -> `bash` with `rg --files` / `find`
- "Fetch a URL" -> `web_fetch`; "search the web" -> a web-search MCP/connector tool when one is configured, otherwise report the capability missing
- "Invoke a skill" -> the `skill` tool with the plugin-prefixed name, e.g. `superpowers:brainstorming`
- "Dispatch a subagent" -> `task(task="...", agent="explore")` for read-only work, or a custom subagent from `~/.vibe/agents/`
- "Create a todo" / "mark complete in todo list" -> the `todo` tool
- "Ask the user a question" -> `ask_user_question`

## Updating

```bash
git -C ~/.vibe/plugins/superpowers pull
```

Then run `/reload-plugins` or start a new session — a running session keeps the plugin content it pinned at startup. The plugin version is tracked in `.version-bump.json` (`plugin.json`), so `scripts/bump-version.sh` keeps it in lockstep with the other harness manifests.

## Troubleshooting

### Plugin not loading

1. `/plugins` should list `superpowers`; files Vibe couldn't load appear there under "Not loaded" with the reason.
2. User plugins in `~/.vibe/plugins/` load in every session. Project plugins in `./.vibe/plugins/` load only when the working directory is trusted — accept the trust prompt or use `--add-dir`.
3. A running session keeps the plugin set it started with: run `/reload-plugins` or start a fresh session after installing.

### Skills not triggering

1. Confirm the plugin is listed by `/plugins` and start a fresh session.
2. Acceptance prompt: `Let's make a react todo list`. A working install loads `brainstorming` before writing any code.
3. The bootstrap arrives through the plugin's `session_start` hook. If the hook fails, Vibe shows a warning and the session continues without its context — run `/reload-plugins` and start a new session.

### Windows

The hook command invokes the repo's polyglot `hooks/run-hook.cmd` directly. Vibe runs hooks in Git Bash when available and otherwise in PowerShell; the wrapper locates bash (or zsh/sh) and falls back to a clean exit when none exists, so the plugin still loads and skills still work — only the bootstrap injection is skipped.
