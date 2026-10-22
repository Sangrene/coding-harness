# Tool adapters

The harness lives in tool-neutral locations, rendered once:

- `AGENTS.md` (or `.agents/AGENTS.md`), `<package>/AGENTS.md`
- `.agents/skills/`, `.agents/agents/`, `.agents/hooks/`, `.agents/harness.yml`

An adapter makes one tool read those files **by reference**. It never holds a
copy of a rule, skill or agent: one source of truth. Adapters are opt-in under
`emit.adapters.<tool>`.

## `claude` (`emit.adapters.claude`)

| Target | Kind | Points at |
|---|---|---|
| `CLAUDE.md` | one-line file from `claude/CLAUDE.md.tmpl` | the memory file |
| `<package.path>/CLAUDE.md` (workspace) | same | `@AGENTS.md` beside it |
| `.claude/skills` | symlink to `../.agents/skills` | the skills directory |
| `.claude/agents` | symlink to `../.agents/agents` | the agents directory |
| `.claude/settings.json` | JSON merge from `claude/settings.snippet.json`, only when `emit.hooks.receipt_check` | `.agents/hooks/receipt-check.sh` |

Symlinks are relative and committed. On a platform without symlink support the
adapter is not installed; the harness itself works unchanged.

## `cursor` (`emit.adapters.cursor`)

Cursor reads `AGENTS.md` natively. The adapter adds the dual background flags
(`{{CURSOR_FLAGS}}`) and the explicit skill reads (`{{CURSOR_STARTUP}}`) inside
the agent files themselves, because Cursor ignores the `skills:` frontmatter.
