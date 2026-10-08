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
unset POLYBRIEF_LAUNCHER || true
mkdir -p "$HOME" "$TMPDIR" "$scratch/work" "$scratch/checklists" "$XDG_CONFIG_HOME"
export PATH="$scratch/bin:/usr/bin:/bin"
fail() { echo "FAIL: $1"; exit 1; }
refused() { local rc=0; "$@" >/dev/null 2>"$scratch/err" || rc=$?; [ "$rc" = 2 ]; }
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
if [[ " $* " == *' --output-format stream-json '* ]]; then
  cat >/dev/null
  printf '%s\n' '{"type":"result","result":"Claude research answer"}'
  exit
fi
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
out=$(cd "$scratch/work" && polybrief -w codex -c "$scratch/checklists/audit2.md" -o log=off -o tool_log=off "$scratch/brief")
grep -q '^PLAN	review	codex	1$' <<< "$out" || fail "-w must keep only codex: $out"
grep -q '^WORKER	review	1	codex	ok	' <<< "$out" || fail "a run must report the worker: $out"
grep -q 'Caller audit method.' <<< "$out" && grep -q 'compare alternatives' <<< "$out" || fail "brief and checklist must reach the worker"
! grep -q '## The change' <<< "$out" || fail "no Git context without -b"

# the crosscheck pattern hands one stage's answers to the next
out=$(polybrief -C "$scratch/work" -p crosscheck -o log=off -o tool_log=off - < "$scratch/brief")
[ "$(grep -c '^WORKER' <<< "$out")" = 4 ] && grep -q 'stage="critique"' <<< "$out" && grep -q '<input-.*from="claude"' <<< "$out" \
  || fail "crosscheck must run two stages: $out"

# A review uses an explicit brief. Panel needs the checklists it names.
g() { git -C "$scratch/repo" -c user.name=t -c user.email=t@t "$@"; }
mkdir -p "$scratch/repo" && g init -q && printf 'a\n' > "$scratch/repo/a.txt" && g add a.txt && g commit -qm init
printf 'b\n' >> "$scratch/repo/a.txt"
out=$(polybrief -C "$scratch/repo" -b HEAD -w codex -o log=off "$root/examples/code-review/references/brief.md")
grep -q 'Review the supplied Git change' <<< "$out" || fail "the explicit review brief must reach the worker: $out"
out=$(polybrief -C "$scratch/repo" -b HEAD -p panel -w codex -c "$root/examples/code-review/references/review-security.md" -c "$root/examples/code-review/references/review-tests.md" -o log=off "$root/examples/code-review/references/brief.md")
grep -q 'Report a missing test' <<< "$out" || fail "panel must use supplied checklists: $out"
mkdir -p "$scratch/own" && printf 'My own tests checklist.\n' > "$scratch/own/review-tests.md"
out=$(polybrief -C "$scratch/repo" -b HEAD -p panel -w codex -c "$root/examples/code-review/references/review-security.md" -c "$scratch/own/review-tests.md" -o log=off "$root/examples/code-review/references/brief.md")
grep -q 'My own tests checklist.' <<< "$out" && ! grep -q 'Report a missing test' <<< "$out" \
  || fail "-c must use the supplied checklist: $out"

# Both copyable skill folders use direct CLI calls and their own briefs.
cp -R "$root/examples/code-review" "$scratch/review-skill"
out=$(cd "$scratch/work" && polybrief -C "$scratch/repo" -b HEAD -p parallel -w codex,opencode \
  -o opencode.model=openai/gpt-5 --label code-review "$scratch/review-skill/references/brief.md")
grep -q '^WORKER[[:space:]]review[[:space:]]1[[:space:]]codex[[:space:]]ok[[:space:]]' <<< "$out" \
  && grep -q '^WORKER[[:space:]]review[[:space:]]1[[:space:]]opencode[[:space:]]ok[[:space:]]' <<< "$out" \
  && grep -q '^RESULT[[:space:]]complete[[:space:]]2$' <<< "$out" \
  && grep -q 'Review the supplied Git change' <<< "$out" \
  || fail "copied code review skill: $out"
cp -R "$root/examples/research" "$scratch/research-skill"
out=$(cd "$scratch/work" && polybrief -C "$root" -p crosscheck -w claude,codex \
  --label research "$scratch/research-skill/references/brief.md")
[ "$(grep -c '^WORKER[[:space:]]' <<< "$out")" = 4 ] \
  && grep -q '^WORKER[[:space:]]analyze[[:space:]]1[[:space:]]claude[[:space:]]ok[[:space:]]' <<< "$out" \
  && grep -q '^WORKER[[:space:]]analyze[[:space:]]1[[:space:]]codex[[:space:]]ok[[:space:]]' <<< "$out" \
  && grep -q '^WORKER[[:space:]]critique[[:space:]]1[[:space:]]claude[[:space:]]ok[[:space:]]' <<< "$out" \
  && grep -q '^WORKER[[:space:]]critique[[:space:]]1[[:space:]]codex[[:space:]]ok[[:space:]]' <<< "$out" \
  && grep -q '^RESULT[[:space:]]complete[[:space:]]4$' <<< "$out" \
  && grep -q 'Should Polybrief keep one' <<< "$out" \
  || fail "copied research skill: $out"
refused polybrief --home "$scratch/own" "$scratch/brief" || fail "--home is no longer accepted"
refused polybrief -C "$scratch/repo" -b HEAD -p panel "$root/examples/code-review/references/brief.md" \
  && grep -q "needs a checklist named 'review-security': pass -c PATH/review-security.md" "$scratch/err" || fail "panel names the missing checklist: $(cat "$scratch/err")"
refused polybrief plan -p panel -c "$root/examples/code-review/references/review-security.md" \
  && grep -q "named 'review-tests'" "$scratch/err" || fail "panel names the second missing checklist"
refused polybrief plan -w '' && grep -q 'needs at least one worker' "$scratch/err" || fail "-w '' is refused"
echo x > "$scratch/Bad_Name.md"; refused polybrief plan -c "$scratch/Bad_Name.md" && grep -q 'bad checklist name' "$scratch/err" || fail "a checklist name outside a-z0-9- is refused"

# -o max_calls overrides the pattern limit; the pattern limit overrides the default
grep -q '^CALLS	2	2$' <<< "$(polybrief plan -p parallel -o max_calls=2)" || fail "-o max_calls must win over the pattern header"
grep -q '^CALLS	2	3$' <<< "$(polybrief plan -p parallel)" || fail "the pattern header must win over the default"

# -o overrides a setting; config shows it with its source
polybrief -C "$scratch/work" -w claude -o claude.effort=max -o log=off -o tool_log=off "$scratch/brief" >/dev/null
grep -q -- '--effort max' "$HOME/claude.args" || fail "-o must reach the worker"
grep -q "^CONFIG	timeout	7	flag$" <<< "$(polybrief config -o timeout=7)" || fail "config must show the override"
refused polybrief config --config "$scratch/sections" || fail "--config is no longer accepted"

# plan starts no worker; twice has four participants
rm -f "$HOME/codex.args"
grep -q '^CALLS	4	4$' <<< "$(polybrief plan -p twice)" || fail "plan must show the calls"
[ ! -e "$HOME/codex.args" ] || fail "plan must start no worker"
grep -q '^PATTERN	parallel	' <<< "$(polybrief patterns)" || fail "patterns must list built-ins"

# yield records the judge's counts
grep -q '^LOGGED' <<< "$(polybrief yield --label parallel -o log="$scratch/runs.tsv" R1 codex=3/2/1)" || fail "yield"
grep -q '	yield	R1	parallel	codex	' "$scratch/runs.tsv" || fail "yield must write the run log"
polybrief -C "$scratch/work" -p parallel -w codex --label review-go -o log="$scratch/runs.tsv" "$scratch/brief" >/dev/null
grep -q 'review-go/review/1/codex' "$scratch/runs.tsv" || fail "run label must reach the worker log"

# -w names the workers of a stage without run lines, so OpenCode needs no pattern of its own.
out=$(polybrief -C "$scratch/work" -w opencode -o opencode.model=openai/gpt-5 -o log=off "$scratch/brief")
grep -q '^WORKER[[:space:]]review[[:space:]]1[[:space:]]opencode[[:space:]]ok[[:space:]]' <<< "$out" \
  && grep -q 'OpenCode public run' <<< "$out" && grep -qx -- '--model' "$scratch/opencode.args" \
  || fail "-w opencode must run OpenCode alone: $out"
plan=$(polybrief plan -w codex,opencode)
grep -q '^PLAN[[:space:]]review[[:space:]]codex,opencode[[:space:]]1$' <<< "$plan" || fail "-w must name the workers of parallel: $plan"
grep -q '^CALLS[[:space:]]3[[:space:]]3$' <<< "$(polybrief plan -w codex,claude,opencode)" || fail "parallel must allow all three workers"
grep -q '^PLAN[[:space:]]review[[:space:]]codex-1,codex-2[[:space:]]1$' <<< "$(polybrief plan -p twice -w codex)" || fail "-w must still filter explicit runs"

# refused before any worker: exit 2
# an OpenCode run without a model is refused before any worker, OpenCode's or another, starts
printf -- '---\nname: mixed\ndescription: codex and opencode\nworkers: codex, opencode\n---\n\n## review\n\n{{brief}}\n' > "$scratch/mixed.md"
for p in "-w opencode" "-p $scratch/mixed.md"; do
  rm -f "$scratch/opencode.args" "$HOME/codex.args"
  rc=0; out=$(polybrief -C "$scratch/work" $p -o log=off "$scratch/brief" 2>"$scratch/err") || rc=$?
  [ "$rc" = 2 ] && grep -q 'opencode.model is required' "$scratch/err" && ! grep -q '^OUT' <<< "$out" \
    && [ ! -e "$scratch/opencode.args" ] && [ ! -e "$HOME/codex.args" ] \
    || fail "$p without opencode.model must be refused before the run starts: rc=$rc $out $(cat "$scratch/err")"
done
refused polybrief -b HEAD || fail "a run needs a brief"
refused polybrief -x "$scratch/brief" || fail "unknown flag"
refused polybrief -c "$scratch/none.md" "$scratch/brief" || fail "missing checklist"
cp "$scratch/checklists/audit2.md" "$scratch/audit2.md"
refused polybrief -c "$scratch/checklists/audit2.md" -c "$scratch/audit2.md" "$scratch/brief" || fail "two checklists with one name"
refused polybrief -w gemini "$scratch/brief" || fail "unknown client"
refused polybrief -o workers=opencode "$scratch/brief" || fail "worker selection uses -w"
refused polybrief -o nosuch=1 "$scratch/brief" || fail "unknown setting"
refused polybrief -o claude.effort=minimal "$scratch/brief" || fail "an effort outside the client's values"
refused polybrief -C "$scratch/work" -b HEAD "$scratch/brief" || fail "-b outside a Git tree"

# the binary works from any place, without a checkout
cp "$scratch/bin/polybrief" "$scratch/relocated"
[ "$("$scratch/relocated" --version)" = "$version" ] && "$scratch/relocated" plan -p crosscheck >/dev/null || fail "relocated binary"
echo 'ok: standalone CLI checks passed'
