# install/ — moved

The installer now lives in [`skills/harness-init/`](../skills/harness-init/SKILL.md)
(with `DETECTION.md` and `CHECKLIST.md` beside it), next to
[`harness-upgrade`](../skills/harness-upgrade/SKILL.md) and
[`harness-doctor`](../skills/harness-doctor/SKILL.md). Point an agent at `skills/harness-init/SKILL.md` inside this checkout. If you
copy the `skills/harness-init/` directory elsewhere, it has no repo above it, so
it will ask for the path to this checkout (HARNESS_ROOT) before it can read `templates/`, `stacks/`
and `harness.schema.yml`.
