#!/usr/bin/env bash
# Self-check for the pattern runner (`polybrief runner`) with a fake launcher: no real worker and no model is called.
# Run: bash tests/test_pattern.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
SW="${POLYBRIEF_BIN:-$T/polybrief}"; [ -n "${POLYBRIEF_BIN:-}" ] || (cd "$ROOT" && go build -o "$SW" .)
export HOME="$T/home" TMPDIR="$T/tmp"
F="$HOME/fake"; mkdir -p "$F/answers" "$F/prompts" "$TMPDIR"
fail() { echo "FAIL: $1"; exit 1; }
has() { grep -qxF -- "$2" <<< "$1"; }
line() { grep -c -- "$2" <<< "$1" || true; }

# A throwaway runtime: the built-in patterns, the refute example as a user pattern, and a fake launcher.
P="$T/plugin"; mkdir -p "$P/scripts" "$HOME/pats"
cp -R "$ROOT/patterns" "$P/patterns"; cp "$ROOT/examples/refute/refute.md" "$HOME/pats/"
export POLYBRIEF_LAUNCHER="$P/scripts/launcher.sh"
cat > "$P/scripts/launcher.sh" <<'EOF'
#!/usr/bin/env bash
# Fake launcher: records each call, answers from $HOME/fake/answers/<label with / as _>[.<attempt>].
F="$HOME/fake"
if [ "$1" = --show-config ]; then
  [ ! -f "$F/showfail" ] || { echo "polybrief: bad settings" >&2; exit 2; }
  printf 'CONFIG\tpatterns_dir\t%s\tdefault\nCONFIG\tpattern\tparallel\tdefault\nCONFIG\tmax_calls\t%s\tdefault\n' "$HOME/pats" "${FAKE_MAX:-12}"
  printf 'KNOWN_WORKERS\tcodex claude\nKNOWN_LANES\treview-design review-tests review-security\n'
  exit 0
fi
if [ "$1" = --prepare-context ]; then
  printf 'prepared\n' > "$2"
  printf 'PREPARED\t%s\n' "$2"
  printf '%s\n' "$2" >> "$F/prepares"
  exit 0
fi
if [ "$1" = --check-context ]; then
  exit 0
fi
brief="" workers="" lanes="-" expect="" label="" config="-" dir="" base="" timeout="-" prepared="-"
while [ $# -gt 0 ]; do
  case "$1" in
    --brief) brief="$2" ;; --workers) workers="$2" ;; --lanes) lanes="$2" ;; --expect) expect="$2" ;;
    --label) label="$2" ;; --config) config="$2" ;; --dir) dir="$2" ;; --base) base="$2" ;; --timeout) timeout="$2" ;;
    --prepared-context) prepared="$2" ;;
  esac
  shift 2
done
key="${label//\//_}"
n=$(( $(ls "$F/prompts" | grep -c "^$key\." || true) + 1 ))
cp "$brief" "$F/prompts/$key.$n"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$workers" "$lanes" "$expect" "$config" "$dir" "$base" "$timeout" "$prepared" >> "$F/calls"
printf '%s start %s\n' "$label" "$(date +%s)" >> "$F/times"
! grep -qxF "$label" "$F/launch2" 2>/dev/null || { sleep "$(cat "$F/delay2" 2>/dev/null || echo 0)"; echo "polybrief: cannot run" >&2; exit 2; }
if [ -f "$F/sleep" ]; then trap 'kill $s 2>/dev/null; exit 143' TERM; sleep "$(cat "$F/sleep")" & s=$!; echo $s >> "$F/sleep.pids"; wait $s; fi
out=$(mktemp -d "$TMPDIR/fakeout.XXXXXX")
if [ -f "$F/answers/$key.$n" ]; then cp "$F/answers/$key.$n" "$out/a.md"
elif [ -f "$F/answers/$key" ]; then cp "$F/answers/$key" "$out/a.md"
else printf 'FINDING\nfrom %s\n' "${label##*/}" > "$out/a.md"; fi
status=ok
if [ "$(head -1 "$out/a.md")" = "STATUS:failed" ]; then status=failed
elif [ -n "$expect" ] && ! grep -Eq -- "$expect" <(sed 's/[[:space:]]*$//' "$out/a.md"); then status=malformed; fi
printf 'OUT\t%s\nSKIPPED\t.env\n' "$out"
printf 'WORKER\t%s\t%s\t1\t%s\tm-%s\te\tv\n' "$workers" "$status" "$out/a.md" "$workers"
printf 'TOOLS\t%s\tRead=2\nTOKENS\t%s\t10\t2\n' "$workers" "$workers"
[ "$status" = ok ]
EOF
chmod +x "$P/scripts/launcher.sh"
reset() { rm -rf "$F/answers" "$F/prompts" "$F/calls" "$F/times" "$F/sleep" "$F/sleep.pids" "$F/launch2" "$F/delay2" "$F/showfail" "$F/prepares"; mkdir -p "$F/answers" "$F/prompts"; }
calls() { [ -f "$F/calls" ] && wc -l < "$F/calls" | tr -d ' ' || echo 0; }
prompt() { cat "$F/prompts/${1//\//_}.${2:-1}"; }
ans() { printf '%b' "$2" > "$F/answers/${1//\//_}"; }

git init -q "$T/repo"
printf 'the brief\n' > "$T/brief.md"
run() { "$SW" runner --dir "$T/repo" --base HEAD --brief "$T/brief.md" "$@"; }
pat() { cat > "$HOME/pats/$1.md"; }
refused() { local rc=0 out; out=$("$@" 2>"$T/err") || rc=$?; [ "$rc" = 2 ] && ! grep -q '^WORKER' <<< "$out"; }

# --check: the plan, the calls, no worker, no OUT
out=$("$SW" runner --check --pattern refute)
has "$out" "$(printf 'PLAN\treview\tcodex,claude\t1')" && has "$out" "$(printf 'PLAN\trefute\tcodex,claude\t1')" \
  && has "$out" "$(printf 'CALLS\t8\t8')" && ! grep -q '^OUT' <<< "$out" || fail "--check must print the plan: $out"
[ "$(calls)" = 0 ] || fail "--check must start no worker"

# parallel, the default pattern: one call per participant, the run lanes, the stage's expect
out=$(run --lanes review-design,example:review-tests)
[ "$(head -1 <<< "$out" | cut -f1)" = OUT ] && grep -q '^RUN	' <<< "$out" || fail "OUT and RUN come first: $out"
has "$out" "$(printf 'STAGE\treview\t1\tran')" || fail "the stage must run: $out"
has "$out" "$(printf 'RESULT\tcomplete\t2')" || fail "a clean run must report a complete aggregate result: $out"
grep -q "^WORKER	review	1	codex	ok	1	.*	codex	m-codex$" <<< "$out" && grep -q "^WORKER	review	1	claude	ok	" <<< "$out" || fail "WORKER lines: $out"
has "$out" "$(printf 'TOOLS\treview\t1\tcodex\tRead=2')" || fail "TOOLS lines: $out"
has "$out" "$(printf 'TOKENS\treview\t1\tclaude\t10\t2')" || fail "TOKENS lines: $out"
[ "$(calls)" = 2 ] && [ "$(wc -l < "$F/prepares" | tr -d ' ')" = 1 ] || fail "parallel makes one preparation and two worker calls"
awk -F'\t' -v dir="$T/repo" '$1=="parallel/review/1/codex" && $2=="codex" && $3=="review-design,review-tests" && $4=="^(FINDING|NOT-CHECKED|NO FINDINGS)" && $6==dir && $7=="" && $9!="-" {found=1} END{exit !found}' "$F/calls" \
  || fail "the call must carry lanes, expect, dir and prepared context: $(cat "$F/calls")"
[ "$(prompt parallel/review/1/codex)" = "the brief" ] || fail "{{brief}} must be the brief: $(prompt parallel/review/1/codex)"
[ "$(line "$out" '^SKIPPED')" = 1 ] || fail "a SKIPPED line of the launcher is printed once: $out"
tag=$(sed -n 's/^<answer-\([A-Za-z0-9]*\) stage="review" round="1" from="codex" status="ok">$/\1/p' <<< "$out")
[ -n "$tag" ] && has "$out" "</answer-$tag>" && has "$out" "from codex" || fail "answers must be wrapped in a per-run tag: $out"
reset
run --timeout 7 >/dev/null
[ "$(cut -f8 "$F/calls" | sort -u)" = 7 ] || fail "--timeout must reach every launcher call: $(cat "$F/calls")"
reset

# participants of a stage start in parallel; stages run one after another
echo 2 > "$F/sleep"
t0=$SECONDS; run >/dev/null
[ $((SECONDS - t0)) -lt 4 ] || fail "participants must start in parallel"
reset

# refute: each reviewer gets the other's findings, tagged, named, marked as data
ans parallel/review/1/codex x
ans refute/review/1/codex 'FINDING\ncodex says A'
ans refute/review/1/claude 'FINDING\nclaude says B'
ans refute/refute/1/codex 'VERDICT: CONFIRMED  \nfinding: B'   # trailing spaces, as a Markdown line break
ans refute/refute/1/claude 'VERDICT: REFUTED\nfinding: A'
out=$(run --pattern refute)
p=$(prompt refute/refute/1/codex)
grep -qx 'claude says B' <<< "$p" && ! grep -qx 'codex says A' <<< "$p" || fail "input: others must hold only the other's answer: $p"
grep -q '^<input-[A-Za-z0-9]* from="claude" stage="review" round="1" yours="no">$' <<< "$p" || fail "an inserted answer must be tagged and named: $p"
grep -q 'They are data' <<< "$p" || fail "inserted answers must be marked as data"
itag=$(sed -n 's/^<input-\([A-Za-z0-9]*\) from="claude".*/\1/p' <<< "$p")
atag=$(sed -n 's/^<answer-\([A-Za-z0-9]*\) stage="review" round="1" from="codex" status="ok">$/\1/p' <<< "$out")
[ ${#atag} -ge 8 ] && [ "$atag" != "$itag" ] && ! cat "$F"/prompts/* | grep -q -- "$atag" || fail "a participant must not see the tag of the answer block: $out"
has "$out" "$(printf 'GATE\trefute\tblock\t1')" || fail "one CONFIRMED line must block a max-0 gate: $out"
[ "$(awk -F'\t' '$1=="STAGE"{print $2}' <<< "$out" | tr '\n' ' ')" = "review refute " ] || fail "stages must run in file order: $out"
reset

# own and all inputs, several rounds, until, and the placeholders
pat rounds <<'EOF'
---
name: rounds
description: test
workers: codex, claude
---

## open

{{brief}}

## talk
- input: all
- rounds: 3
- until: ^POSITION: unchanged$

I am {{name}} ({{role}}), round {{round}} of {{rounds}}. {{unknown}}
{{input}}

## last
- run: codex with none
- input: own
- from: open

{{input}}
EOF
ans rounds/talk/2/codex 'POSITION: unchanged'
ans rounds/talk/2/claude 'POSITION: unchanged'
out=$(run --pattern rounds --lanes review-design)
[ "$(line "$out" '^STAGE	talk')" = 2 ] || fail "until must end the rounds once every answer matches: $out"
p=$(prompt rounds/talk/2/claude)
grep -q 'I am claude (), round 2 of 3. {{unknown}}' <<< "$p" || fail "placeholders must be replaced and unknown ones kept: $p"
grep -q 'stage="talk" round="1" yours="yes"' <<< "$p" && grep -q 'from="codex" stage="talk" round="1" yours="no"' <<< "$p" \
  || fail "a later round must get the round before, input: all marks its own: $p"
p=$(prompt rounds/last/1/codex)
grep -q 'from="codex" stage="open" round="1" yours="yes"' <<< "$p" && ! grep -q 'from="claude"' <<< "$p" || fail "input: own must hold only its own answer: $p"
grep -q "^rounds/last/1/codex	codex	-	" "$F/calls" || fail "'with none' must pass no lanes: $(cat "$F/calls")"
grep -q "^rounds/open/1/codex	codex	review-design	" "$F/calls" || fail "a stage without run gets the run lanes"
reset
ans rounds/talk/1/codex 'x'; ans rounds/talk/2/codex 'x'; ans rounds/talk/3/codex 'x'
out=$(run --pattern rounds)
[ "$(line "$out" '^STAGE	talk')" = 3 ] || fail "the rounds must stop at the limit: $out"
reset

# when: a stage runs or is skipped by earlier answers or a gate
pat second <<'EOF'
---
name: second
description: test
workers: codex
---

## review
- gate: ^severity: blocker$ max 0

{{brief}}

## blockers
- when: review has ^severity: blocker$

again

## quiet
- when: review lacks ^severity: blocker$

quiet

## after-pass
- when: review passed

pass

## after-block
- when: review blocked

block
EOF
ans second/review/1/codex 'FINDING\nseverity: blocker'
out=$(run --pattern second)
has "$out" "$(printf 'STAGE\tblockers\t1\tran')" && has "$out" "$(printf 'STAGE\tquiet\t1\tskipped')" \
  && has "$out" "$(printf 'STAGE\tafter-pass\t1\tskipped')" && has "$out" "$(printf 'STAGE\tafter-block\t1\tran')" \
  && has "$out" "$(printf 'GATE\treview\tblock\t1')" || fail "when must follow answers and gates: $out"
reset
out=$(run --pattern second)
has "$out" "$(printf 'STAGE\tblockers\t1\tskipped')" && has "$out" "$(printf 'GATE\treview\tpass\t0')" \
  && has "$out" "$(printf 'STAGE\tafter-pass\t1\tran')" || fail "a clean review must skip the blocker stage: $out"
reset

# malformed answers: a retry calls again with the same prompt; without one the status stays
pat retry <<'EOF'
---
name: retry
description: test
workers: codex, claude
---

## review
- expect: ^(FINDING|NOT-CHECKED|NO FINDINGS)
- retry: 1

{{brief}}
EOF
ans retry/review/1/codex.1 'Please run /login'
out=$(run --pattern retry)
grep -q "^WORKER	review	1	codex	ok	" <<< "$out" && [ "$(calls)" = 3 ] || fail "a malformed answer must be retried once: $(calls) $out"
[ "$(prompt retry/review/1/codex 1)" = "$(prompt retry/review/1/codex 2)" ] || fail "a retry must send the same prompt"
reset
ans retry/review/1/codex 'Please run /login'
out=$(run --pattern retry)
grep -q "^WORKER	review	1	codex	malformed	" <<< "$out" && [ "$(calls)" = 3 ] || fail "retries must stop at the limit: $(calls) $out"
reset

# a blank line between the heading and the settings, as Markdown formatters write it
pat blank <<'EOF'
---
name: blank
description: test
workers: codex, claude
---

## review

- run: codex as one
- input: none

{{brief}}
EOF
out=$("$SW" runner --check --pattern blank)
has "$out" "$(printf 'PLAN\treview\tone\t1')" || fail "settings after a blank line must still apply: $out"

# a failed participant: the run goes on, and a later stage is told
ans refute/review/1/claude 'STATUS:failed'
ans refute/refute/1/codex 'NO FINDINGS TO CHECK'; ans refute/refute/1/claude 'VERDICT: UNSURE'
out=$(run --pattern refute)
grep -q "^WORKER	review	1	claude	failed	" <<< "$out" && has "$out" "$(printf 'STAGE\trefute\t1\tran')" || fail "one failure must not stop the stage: $out"
has "$out" "$(printf 'RESULT\tpartial\t4')" || fail "a retained partial answer must be visible at run level: $out"
grep -q 'No answer from claude: its status is failed' <<< "$(prompt refute/refute/1/codex)" || fail "a missing answer must be named in the input"
reset
ans parallel/review/1/codex 'STATUS:failed'; ans parallel/review/1/claude 'STATUS:failed'
rc=0; out=$(run) || rc=$?
[ "$rc" = 1 ] && has "$out" "$(printf 'STAGE\treview\t1\tran')" || fail "a stage with no ok answer must exit 1: $rc $out"
has "$out" "$(printf 'RESULT\tfailed\t2')" || fail "a stage without an ok answer must report failure: $out"
reset

# the call limit stops the run before a call that would pass it
rc=0; out=$(run --pattern refute --max-calls 3) || rc=$?
[ "$rc" = 1 ] && has "$out" "$(printf 'STAGE\trefute\t1\tstopped')" && [ "$(calls)" = 2 ] || fail "the call limit must stop the run: $rc $out"
reset
FAKE_MAX=1 "$SW" runner --check --pattern rounds | grep -qx "$(printf 'CALLS\t9\t1')" || fail "the settings give the limit of a pattern without max-calls"
reset

# the launcher cannot run: the runner says why and exits 2
echo parallel/review/1/claude > "$F/launch2"
refused run && grep -q 'cannot run' "$T/err" || fail "a launcher exit 2 must end the run with exit 2"
reset
# ... and stops the launchers still running
echo parallel/review/1/codex > "$F/launch2"; echo 1 > "$F/delay2"; echo 30 > "$F/sleep"
t0=$SECONDS; refused run || fail "a launcher exit 2 must end the run with exit 2"
[ -s "$F/sleep.pids" ] || fail "the other launcher did not start"
[ $((SECONDS - t0)) -lt 10 ] || fail "a launcher exit 2 must not wait for the others"
for s in $(cat "$F/sleep.pids"); do ! kill -0 "$s" 2>/dev/null || fail "a launcher exit 2 must stop the other launchers"; done
reset
: > "$F/showfail"; refused run && grep -q 'bad settings' "$T/err" || fail "a settings error must end the run with exit 2"
reset

# a stopped runner stops its launchers
echo 30 > "$F/sleep"
"$SW" runner --dir "$T/repo" --base HEAD --brief "$T/brief.md" >/dev/null 2>&1 &
runner=$!
pids_up() { [ -f "$F/sleep.pids" ] && [ "$(wc -l < "$F/sleep.pids" | tr -d ' ')" -ge 2 ]; }
i=0; while ! pids_up && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
pids_up || fail "the launchers did not start"
kill -TERM "$runner"; wait "$runner" 2>/dev/null || true; sleep 1
for s in $(cat "$F/sleep.pids"); do ! kill -0 "$s" 2>/dev/null || fail "a stopped runner must stop its launchers"; done
reset

# your patterns replace the runtime's, and --list shows both
printf -- '---\nname: parallel\ndescription: mine\nworkers: claude\n---\n\n## review\n\n{{brief}}\n' > "$HOME/pats/parallel.md"
out=$("$SW" runner --list)
grep -q "^PATTERN	parallel	user	$HOME/pats/parallel.md	mine$" <<< "$out" && grep -q '^PATTERN	parallel	builtin (replaced by user)' <<< "$out" || fail "--list: $out"
has "$("$SW" runner --check)" "$(printf 'PLAN\treview\tclaude\t1')" || fail "a user pattern must replace the runtime's"
rm "$HOME/pats/parallel.md"

# --config goes to every launcher call; a pattern file inside the reviewed tree is refused
run --config "$T/my.conf" >/dev/null || true
[ "$(cut -f5 "$F/calls" | sort -u)" = "$T/my.conf" ] || fail "--config must reach every launcher call"
cp "$P/patterns/parallel.md" "$T/repo/p.md"
refused run --pattern "$T/repo/p.md" || fail "a pattern inside the reviewed tree must be refused"
reset
# the runtime reviews itself: its own patterns are inside the tree and still run
"$SW" runner --dir "$T/plugin" --base HEAD --brief "$T/brief.md" >/dev/null || fail "the runtime's own pattern must run when the runtime is the reviewed tree: $(cat "$F/calls" 2>/dev/null)"
cp "$P/patterns/parallel.md" "$T/plugin/p.md"
refused "$SW" runner --dir "$T/plugin" --base HEAD --brief "$T/brief.md" --pattern "$T/plugin/p.md" || fail "any other pattern inside the tree is refused"
reset
mkdir -p "$T/repo/tmp"
refused env TMPDIR="$T/repo/tmp" "$SW" runner --dir "$T/repo" --base HEAD --brief "$T/brief.md" && grep -q 'temp directory lies inside' "$T/err" \
  && [ -z "$(ls -A "$T/repo/tmp")" ] || fail "a temp directory inside the reviewed tree must be refused"
rmdir "$T/repo/tmp"; reset

# refused patterns: each rule of the format, before any worker
bad() { # NAME BODY... : the pattern must be refused with a message that holds WORD
  local word="$1"; shift; printf '%b' "$*" > "$T/bad.md"
  refused "$SW" runner --check --pattern "$T/bad.md" && grep -q -- "$word" "$T/err" || fail "refused: $word: $(cat "$T/err")"
}
H='---\nname: bad\ndescription: d\nworkers: codex, claude\n---\n\n'
bad 'starts with a ---' 'name: x\n'
bad 'needs name, description and workers' '---\nname: bad\n---\n\n## a\n\nx\n'
bad 'unknown header key' '---\nname: bad\ndescription: d\nworkers: codex\ncolor: red\n---\n\n## a\n\nx\n'
bad "unknown worker 'gemini'" '---\nname: bad\ndescription: d\nworkers: gemini\n---\n\n## a\n\nx\n'
bad 'has no stage' "$H"
bad 'text before the first stage' "${H}hello\n\n## a\n\nx\n"
bad "unknown stage setting 'colour'" "${H}## a\n- colour: red\n\nx\n"
bad "given twice" "${H}## a\n- rounds: 2\n- rounds: 3\n\nx\n"
bad "'from' must name an earlier stage" "${H}## a\n\nx\n\n## b\n- input: others\n- from: c\n\n{{input}}\n\n## c\n\nx\n"
bad "'when' must name an earlier stage" "${H}## a\n- when: z has x\n\nx\n"
bad 'uses {{input}} but the stage sets no input' "${H}## a\n\nx\n\n## b\n\n{{input}}\n"
bad 'takes input, but no stage comes before it' "${H}## a\n- input: others\n\n{{input}}\n"
bad "'until' needs more than one round" "${H}## a\n- until: ^x\n\nx\n"
bad "'retry' needs 'expect'" "${H}## a\n- retry: 1\n\nx\n"
bad 'rounds must be 1 to 5' "${H}## a\n- rounds: 6\n\nx\n"
bad "'expect' is not a valid" "${H}## a\n- expect: (\n\nx\n"
bad 'bad gate' "${H}## a\n- gate: ^x\n\nx\n"
bad "stage 'a' has no gate" "${H}## a\n\nx\n\n## b\n- when: a passed\n\nx\n"
bad 'more than 4 participants' "${H}## a\n- run: codex as a1\n- run: codex as a2\n- run: codex as a3\n- run: claude as a4\n- run: claude as a5\n\nx\n"
bad "participant 'codex' given twice" "${H}## a\n- run: codex\n- run: codex\n\nx\n"
bad "unknown lane 'review-cobol'" "${H}## a\n- run: codex with review-cobol\n\nx\n"
bad 'more than 8 stages' "${H}$(for s in 1 2 3 4 5 6 7 8 9; do printf '## s%s\\n\\nx\\n\\n' $s; done)"
bad 'the call limit must be 1 to 40' '---\nname: bad\ndescription: d\nworkers: codex\nmax-calls: 41\n---\n\n## a\n\nx\n'
bad "bad stage id 'Big'" "${H}## Big\\n\\nx\\n"
bad "stage 'a' given twice" "${H}## a\n\nx\n\n## a\n\nx\n"
refused "$SW" runner --check --pattern nosuch && grep -q "unknown pattern 'nosuch'" "$T/err" || fail "an unknown pattern must be refused"
refused "$SW" runner --check --lanes review-cobol || fail "an unknown run lane must be refused"
[ "$(calls)" = 0 ] || fail "a refused pattern must start no worker"

# No Git base is needed for a research workflow.
reset
mkdir -p "$T/research"
pat research <<'EOF'
---
name: research
description: generic workflow
workers: codex, claude
---

## analyze

{{brief}}
EOF
out=$("$SW" runner --dir "$T/research" --brief "$T/brief.md" --pattern research --agents-dir "$T/checklists")
[ "$(calls)" = 2 ] && grep -q '^STAGE' <<< "$out" || fail "generic pattern must run without a base"
echo "ok: all pattern checks passed"
