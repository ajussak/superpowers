# Mistral Vibe Code Tool Mapping

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). On Mistral Vibe Code these resolve to the tools below. Vibe calls tools by their short names; the same tools have namespaced full names (e.g. `file_system.bash`) in hook matchers and permission tables.

| Action skills request | Vibe Code equivalent |
|----------------------|----------------------|
| Read a file | `read_file` |
| Read multiple files | `read_file` (call multiple times) |
| Create a new file | `write_file` |
| Edit a file | `edit` |
| Run a shell command | `bash` |
| Search file contents | `grep` |
| Find files by path or pattern | `bash` with `rg --files` / `find`, or `grep` |
| Fetch a URL | `web_fetch` |
| Search the web | a web-search tool if one is in your tool list (MCP/connector), otherwise report the capability missing |
| Invoke a skill | `skill` tool with the plugin-prefixed name, e.g. `superpowers:brainstorming` |
| Dispatch a subagent | `task(task="...", agent="explore")` or a custom subagent name |
| Task tracking ("create a todo", "mark complete") | `todo` tool |
| Ask the user a question | `ask_user_question` |

## Instructions file

When a skill mentions "your instructions file", on Vibe Code this is **`AGENTS.md`** in the project directory (loaded from trusted folders), or `~/.vibe/AGENTS.md` globally.

## Skill invocation

Vibe Code follows the Agent Skills specification. Skills shipped by this plugin are exposed as `superpowers:<skill-name>` and as the slash commands `/superpowers:<skill-name>`. Invoke them with the `skill` tool using that plugin-prefixed name:

```
skill(name="superpowers:brainstorming")
```

The `using-superpowers` bootstrap is injected automatically at session start by the plugin's `session_start` hook (`ai.mistral.vibe/hooks.toml`) — you are already following it, do not re-load it.

## Subagent dispatch

Use `task` to delegate work to a subagent, for example `task(task="...", agent="explore")` for read-only exploration, or a custom subagent defined in `~/.vibe/agents/` / `./.vibe/agents/`. Paste fully filled Superpowers prompt templates (implementer, reviewer) into `task`. Subagents can't ask the user questions. If subagents are disabled (`enable_subagents = false`), do the work inline rather than inventing tool calls.

## Task tracking

Use the `todo` tool for checklist tracking. Create one todo per skill checklist item, mark in_progress/completed as you go.
