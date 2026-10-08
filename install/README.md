# install/ — moved

The installer now lives in [`skills/harness-init/`](../skills/harness-init/SKILL.md)
(with `DETECTION.md` and `CHECKLIST.md` beside it), next to
[`harness-upgrade`](../skills/harness-upgrade/SKILL.md) and
[`harness-doctor`](../skills/harness-doctor/SKILL.md). Prefer the plugin:
`/plugin marketplace add <path-or-owner/repo>`, then
`/plugin install coding-harness@coding-harness`, then `/coding-harness:harness-init`
— it resolves templates and stack packs from the plugin root on its own.
Standalone still works: point an agent at `skills/harness-init/SKILL.md` inside
this checkout, or copy the whole `skills/harness-init/` directory to
`~/.claude/skills/`; a copied skill has no repo above it, so it will ask for the
path to this checkout (HARNESS_ROOT) before it can read `templates/`, `stacks/`
and `harness.schema.yml`.
