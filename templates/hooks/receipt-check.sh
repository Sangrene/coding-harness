#!/bin/sh
# receipt-check.sh — SubagentStop hook for a coding-harness install.
#
# Rejects a harness agent's final message unless its last six lines are the six
# receipt fields, one line each, in order (.claude/skills/orchestrator/receipt.md),
# and rejects a test-owning builder's `STATUS: done` unless OUTCOME contains the
# whole words "red" and "green" (case-insensitive; "failed"/"passed" do not count).
#
# Usage (from .claude/settings.json, matcher limited to harness agents):
#   receipt-check.sh [--tdd agent-a,agent-b]
#
# Input:  SubagentStop JSON on stdin (agent_type, last_assistant_message,
#         stop_hook_active, ...).
# Output: nothing + exit 0 to allow; {"decision":"block","reason":...} + exit 0
#         to send the subagent back with the reason as its next instruction.
# Fails open: no jq and no python3, or no last_assistant_message → warn, exit 0.
# A hook that blocks on its own breakage is worse than no hook.

tdd_agents=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tdd) shift; tdd_agents="${1:-}" ;;
    --tdd=*) tdd_agents="${1#--tdd=}" ;;
    *) printf 'receipt-check: unknown argument %s (ignored)\n' "$1" >&2 ;;
  esac
  [ $# -gt 0 ] && shift
done

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  tool=jq
elif command -v python3 >/dev/null 2>&1; then
  tool=python3
else
  echo "receipt-check: neither jq nor python3 found; receipt not checked" >&2
  exit 0
fi

# field <name> — print a top-level string/bool field of the input JSON, or "".
field() {
  if [ "$tool" = jq ]; then
    printf '%s' "$input" | jq -r --arg k "$1" '.[$k] // "" | tostring' 2>/dev/null
  else
    printf '%s' "$input" | python3 -I -c '
import json, sys
try:
    v = json.load(sys.stdin).get(sys.argv[1], "")
except Exception:
    v = ""
if isinstance(v, bool):
    v = "true" if v else "false"
sys.stdout.write("" if v is None else str(v))
' "$1" 2>/dev/null
  fi
}

# block <reason> — emit the block decision as JSON and stop.
block() {
  if [ "$tool" = jq ]; then
    jq -cn --arg r "$1" '{decision: "block", reason: $r}'
  else
    python3 -I -c 'import json, sys; print(json.dumps({"decision": "block", "reason": sys.argv[1]}))' "$1"
  fi
  exit 0
}

[ "$(field stop_hook_active)" = "true" ] && exit 0

agent=$(field agent_type)
msg=$(field last_assistant_message)

if [ -z "$msg" ]; then
  echo "receipt-check: no last_assistant_message in hook input; receipt not checked" >&2
  exit 0
fi

# norm <name> — lowercase, trimmed, plugin/namespace prefix ("plugin:agent",
# "dir/agent") and an agent-file suffix (".agent.md", ".md") removed.
norm() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    -e 's/^.*[:\/]//' -e 's/\.agent\.md$//' -e 's/\.md$//'
}

# Tail of the message: CRs removed, trailing blank lines and one closing code
# fence removed (agents often echo the ```text block from the template), then
# the last six lines.
tail6=$(printf '%s\n' "$msg" | tr -d '\r' | awk '
  { line[NR] = $0 }
  END {
    n = NR
    while (n > 0 && line[n] ~ /^[[:space:]]*$/) n--
    if (n > 0 && line[n] ~ /^[[:space:]]*```[[:space:]]*$/) n--
    while (n > 0 && line[n] ~ /^[[:space:]]*$/) n--
    s = n - 5; if (s < 1) s = 1
    for (i = s; i <= n; i++) print line[i]
  }')

receipt_rule="End your final message with exactly the six receipt lines, in order, nothing after them: STATUS: done | blocked | needs-orchestrator / SCOPE: <your agent name> / FILES: ... / OUTCOME: ... / BLOCKERS: ... / NEXT: ... Every field is ONE line: BLOCKERS must be one line; separate items with '; ' (same for FILES and OUTCOME). See .claude/skills/orchestrator/receipt.md."

# Trailing prose: a NEXT: line exists but is not the last line.
last=$(printf '%s\n' "$tail6" | tail -n 1)
case "$last" in
  NEXT:*) ;;
  *)
    if printf '%s\n' "$msg" | grep -q '^NEXT:'; then
      block "Your receipt is not the end of your final message: remove everything after the NEXT: line and resend. $receipt_rule"
    fi
    ;;
esac

i=0
status=""; scope=""; outcome=""
for key in STATUS SCOPE FILES OUTCOME BLOCKERS NEXT; do
  i=$((i + 1))
  l=$(printf '%s\n' "$tail6" | sed -n "${i}p")
  case "$l" in
    "$key:"*) ;;
    *) block "Receipt line $i of the last six must start with '$key:' but is: '$(printf '%s' "$l" | cut -c1-80)'. A field spread over several lines (a bulleted BLOCKERS list) breaks this. $receipt_rule" ;;
  esac
  val=$(printf '%s' "${l#"$key:"}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  case "$key" in
    STATUS) status=$val ;;
    SCOPE) scope=$val ;;
    OUTCOME) outcome=$val ;;
  esac
done

case "$status" in
  done|blocked|needs-orchestrator) ;;
  *) block "STATUS must be exactly one of done, blocked, needs-orchestrator; got '$status'. Fix the STATUS line and resend the receipt." ;;
esac

a=$(norm "$agent")
s=$(norm "$scope")
if [ -n "$a" ] && [ "$a" != "$s" ]; then
  # Accept a scope missing only the workspace prefix (agent api-domain-builder,
  # SCOPE domain-builder).
  case "$a" in
    *-"$s") [ -n "$s" ] || block "SCOPE is empty; it must be your agent name, '$agent'. Fix the SCOPE line and resend the receipt." ;;
    *) block "SCOPE must be your agent name, '$agent'; got '$scope'. Fix the SCOPE line and resend the receipt." ;;
  esac
fi

# Test-owning builders: `done` must report the red run and the green run.
if [ "$status" = done ] && [ -n "$tdd_agents" ] && [ -n "$a" ]; then
  is_tdd=no
  old_ifs=$IFS; IFS=,
  for t in $tdd_agents; do
    [ "$(norm "$t")" = "$a" ] && is_tdd=yes
  done
  IFS=$old_ifs
  if [ "$is_tdd" = yes ]; then
    lc=$(printf '%s' "$outcome" | tr 'A-Z' 'a-z')
    has_red=no; has_green=no
    # Whole words only: "red"/"green", never fail*/pass* ("3 passed, 0 failed"
    # is one green run, not a red one) and never inside a word ("covered").
    printf '%s' "$lc" | grep -Eq '(^|[^a-z0-9_])red([^a-z0-9_]|$)' && has_red=yes
    printf '%s' "$lc" | grep -Eq '(^|[^a-z0-9_])green([^a-z0-9_]|$)' && has_green=yes
    if [ "$has_red" = no ] || [ "$has_green" = no ]; then
      missing=""
      [ "$has_red" = no ] && missing="the word 'red' with the red run (the test you watched fail first, and why it failed)"
      if [ "$has_green" = no ]; then
        [ -n "$missing" ] && missing="$missing and "
        missing="${missing}the word 'green' with the green run (the passing count after implementation)"
      fi
      block "You own tests, so STATUS: done needs OUTCOME to report both halves of the tdd loop, labelled with the literal words 'red' and 'green' ('failed'/'passed' do not count); it is missing $missing. If you never ran the test red before implementing, do it now: revert or stub the implementation, run the targeted test, watch it fail, restore, run it green. Then resend the receipt with both runs in OUTCOME, e.g. 'red: 2 failing (NotFound not returned); green: 2 passing'."
    fi
  fi
fi

exit 0
