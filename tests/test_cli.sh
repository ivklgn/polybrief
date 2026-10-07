#!/usr/bin/env bash
# The public command line of the polybrief binary, with fake workers; no model calls.
# Run: bash tests/test_cli.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d)"; trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"
if [ -n "${POLYBRIEF_BIN:-}" ]; then cp "$POLYBRIEF_BIN" "$scratch/bin/polybrief"; else (cd "$root" && go build -o "$scratch/bin/polybrief" .); fi
export HOME="$scratch/home" TMPDIR="$scratch/tmp" CODEX_HOME="$scratch/home/.codex"
export XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$HOME/.state"
unset POLYBRIEF_CONFIG POLYBRIEF_PATTERNS_DIR POLYBRIEF_LAUNCHER || true
mkdir -p "$HOME" "$TMPDIR" "$scratch/work" "$scratch/checklists"
export PATH="$scratch/bin:/usr/bin:/bin"
fail() { echo "FAIL: $1"; exit 1; }
printf 'log = off\ntool_log = off\n' > "$scratch/config"
cat > "$scratch/bin/codex" <<'FAKE'
#!/usr/bin/env bash
[ "${1:-}" != --version ] || { echo fake-codex; exit; }
case " $* " in *' exec -s read-only --ignore-user-config --ephemeral -c project_doc_max_bytes=0 '*) ;; *) exit 9 ;; esac
echo "$*" > "$HOME/codex.args"
output=""
while [ $# -gt 0 ]; do
  if [ "$1" = -o ]; then output="$2"; shift; fi
  shift
done
{ echo 'FINDING'; cat; } > "$output"
FAKE
cat > "$scratch/bin/claude" <<'FAKE'
#!/usr/bin/env bash
[ "${1:-}" != --version ] || { echo fake-claude; exit; }
case " $* " in *' -p --tools Read,Grep,Glob --strict-mcp-config --setting-sources  --no-session-persistence '*) ;; *) exit 9 ;; esac
echo "$*" > "$HOME/claude.args"
echo FINDING
cat
FAKE
cat > "$scratch/bin/opencode" <<'FAKE'
#!/usr/bin/env bash
[ "${1:-}" != --version ] || { echo fake-opencode; exit; }
case " $* " in *' run --pure --format json --agent polybrief-readonly --dir '*) ;; *) exit 9 ;; esac
scratch="$(cd "$(dirname "$0")/.." && pwd -P)"
printf '%s\n' "$@" > "$scratch/opencode.args"
cat >/dev/null
printf '%s\n' '{"type":"text","part":{"type":"text","text":"FINDING\nOpenCode public run"}}'
FAKE
chmod +x "$scratch/bin/codex" "$scratch/bin/claude" "$scratch/bin/opencode"

version="$(polybrief --version)"
[[ "$version" =~ ^polybrief\ [0-9A-Za-z.+-]+$ ]] || fail "version: $version"
grep -q '^Usage:' <<< "$(polybrief -h)" || fail "help"
printf 'compare alternatives\n' > "$scratch/brief"
printf -- '---\nname: audit2\n---\nCaller audit method.\n' > "$scratch/checklists/audit2.md"

# a run without -b: the default pattern, one client, a checklist, no Git context
out=$(cd "$scratch/work" && polybrief -w codex -c "$scratch/checklists/audit2.md" --config "$scratch/config" "$scratch/brief")
grep -q '^PLAN	review	codex	1$' <<< "$out" || fail "-w must keep only codex: $out"
grep -q '^WORKER	review	1	codex	ok	' <<< "$out" || fail "a run must report the worker: $out"
grep -q 'Caller audit method.' <<< "$out" && grep -q 'compare alternatives' <<< "$out" || fail "brief and checklist must reach the worker"
! grep -q '## The change' <<< "$out" || fail "no Git context without -b"

# the crosscheck pattern hands one stage's answers to the next
out=$(polybrief -C "$scratch/work" -p crosscheck --config "$scratch/config" - < "$scratch/brief")
[ "$(grep -c '^WORKER' <<< "$out")" = 4 ] && grep -q 'stage="critique"' <<< "$out" && grep -q '<input-.*from="claude"' <<< "$out" \
  || fail "crosscheck must run two stages: $out"

# -o overrides a setting; config shows it with its source
polybrief -C "$scratch/work" -w claude -o claude.effort=max --config "$scratch/config" "$scratch/brief" >/dev/null
grep -q -- '--effort max' "$HOME/claude.args" || fail "-o must reach the worker"
grep -q "^CONFIG	timeout	7	flag$" <<< "$(polybrief config -o timeout=7 --config "$scratch/config")" || fail "config must show the override"
printf '[codex]\neffort = high\n[claude]\nmodel = sonnet\n' > "$scratch/sections"
grep -q "^CONFIG	codex.effort	high	file:2$" <<< "$(polybrief config --config "$scratch/sections")" || fail "a section key is a dotted key"

# plan starts no worker; twice has four participants
rm -f "$HOME/codex.args"
grep -q '^CALLS	4	4$' <<< "$(polybrief plan -p twice)" || fail "plan must show the calls"
[ ! -e "$HOME/codex.args" ] || fail "plan must start no worker"
grep -q '^PATTERN	parallel	' <<< "$(polybrief patterns)" || fail "patterns must list built-ins"

# yield records the judge's counts
printf 'log = %s/runs.tsv\n' "$scratch" > "$scratch/logconf"
grep -q '^LOGGED' <<< "$(polybrief yield --label parallel --config "$scratch/logconf" R1 codex=3/2/1)" || fail "yield"
grep -q '	yield	R1	parallel	codex	' "$scratch/runs.tsv" || fail "yield must write the run log"
polybrief -C "$scratch/work" -p parallel -w codex --label review-go --config "$scratch/logconf" "$scratch/brief" >/dev/null
grep -q 'review-go/review/1/codex' "$scratch/runs.tsv" || fail "run label must reach the worker log"

# -w names the workers of a stage without run lines, so OpenCode needs no pattern of its own.
out=$(polybrief -C "$scratch/work" -w opencode -o opencode.model=openai/gpt-5 --config "$scratch/config" "$scratch/brief")
grep -q '^WORKER[[:space:]]review[[:space:]]1[[:space:]]opencode[[:space:]]ok[[:space:]]' <<< "$out" \
  && grep -q 'OpenCode public run' <<< "$out" && grep -qx -- '--model' "$scratch/opencode.args" \
  || fail "-w opencode must run OpenCode alone: $out"
plan=$(polybrief plan -w codex,opencode)
grep -q '^PLAN[[:space:]]review[[:space:]]codex,opencode[[:space:]]1$' <<< "$plan" || fail "-w must name the workers of parallel: $plan"
grep -q '^CALLS[[:space:]]3[[:space:]]3$' <<< "$(polybrief plan -w codex,claude,opencode)" || fail "parallel must allow all three workers"
grep -q '^PLAN[[:space:]]review[[:space:]]codex-1,codex-2[[:space:]]1$' <<< "$(polybrief plan -p twice -w codex)" || fail "-w must still filter explicit runs"

# refused before any worker: exit 2
refused() { local rc=0; "$@" >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ]; }
# an OpenCode run without a model is refused before any worker, OpenCode's or another, starts
printf -- '---\nname: mixed\ndescription: codex and opencode\nworkers: codex, opencode\n---\n\n## review\n\n{{brief}}\n' > "$scratch/mixed.md"
for p in "-w opencode" "-p $scratch/mixed.md"; do
  rm -f "$scratch/opencode.args" "$HOME/codex.args"
  rc=0; out=$(polybrief -C "$scratch/work" $p --config "$scratch/config" "$scratch/brief" 2>"$scratch/err") || rc=$?
  [ "$rc" = 2 ] && grep -q 'opencode.model is required' "$scratch/err" && ! grep -q '^OUT' <<< "$out" \
    && [ ! -e "$scratch/opencode.args" ] && [ ! -e "$HOME/codex.args" ] \
    || fail "$p without opencode.model must be refused before the run starts: rc=$rc $out $(cat "$scratch/err")"
done
refused polybrief --config "$scratch/config" || fail "a run needs a brief"
refused polybrief -x "$scratch/brief" || fail "unknown flag"
refused polybrief -c "$scratch/none.md" "$scratch/brief" || fail "missing checklist"
cp "$scratch/checklists/audit2.md" "$scratch/audit2.md"
refused polybrief -c "$scratch/checklists/audit2.md" -c "$scratch/audit2.md" "$scratch/brief" || fail "two checklists with one name"
refused polybrief -w gemini "$scratch/brief" || fail "unknown client"
refused polybrief -o nosuch=1 "$scratch/brief" || fail "unknown setting"
refused polybrief -o claude.effort=minimal "$scratch/brief" || fail "an effort outside the client's values"
refused polybrief -C "$scratch/work" -b HEAD "$scratch/brief" || fail "-b outside a Git tree"
printf '[gemini]\nmodel = x\n' > "$scratch/badsec"
refused polybrief config --config "$scratch/badsec" || fail "unknown section"

# the binary works from any place, without a checkout
cp "$scratch/bin/polybrief" "$scratch/relocated"
[ "$("$scratch/relocated" --version)" = "$version" ] && "$scratch/relocated" plan -p crosscheck >/dev/null || fail "relocated binary"
echo 'ok: standalone CLI checks passed'
