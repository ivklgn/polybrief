#!/usr/bin/env bash
# Self-check for the launcher (`polybrief launch`) with fake codex and claude CLIs: no real model is called.
# Run: bash tests/test_review.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
S="${POLYBRIEF_BIN:-$T/polybrief}"; [ -n "${POLYBRIEF_BIN:-}" ] || (cd "$ROOT" && go build -o "$S" .)

# The fake CLIs take their orders from files in a HOME of their own.
export HOME="$T/home" TMPDIR="$T/tmp" CODEX_HOME="$T/home/.codex" XDG_CONFIG_HOME="$T/home/.config" XDG_DATA_HOME="$T/home/.data" XDG_STATE_HOME="$T/home/.state"
unset POLYBRIEF_CONFIG POLYBRIEF_PATTERNS_DIR || true
A="$T/agents"; mkdir -p "$A"
printf -- '---\nname: review-design\n---\nDesign checklist fixture.\n' > "$A/review-design.md"
printf -- '---\nname: review-tests\n---\nTests checklist fixture.\n' > "$A/review-tests.md"
F="$HOME/fake"; mkdir -p "$F" "$TMPDIR" "$CODEX_HOME" "$XDG_CONFIG_HOME/polybrief"
mkdir -p "$XDG_DATA_HOME/opencode"
printf '{"test":"credential"}\n' > "$XDG_DATA_HOME/opencode/auth.json"
CONF="$XDG_CONFIG_HOME/polybrief/polybrief.conf" LOG="$XDG_STATE_HOME/polybrief/polybrief-runs.tsv"
toml() { printf 'model = "test-model"\nmodel_reasoning_effort = "high"\n\n[profiles.x]\nmodel = "other"\n' > "$CODEX_HOME/config.toml"; }
toml
g() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }
fail() { echo "FAIL: $1"; exit 1; }
row() { printf '%s\n' "$1" | awk -F'\t' -v w="$2" '$1=="WORKER" && $2==w{print $3}'; }
fld() { printf '%s\n' "$1" | awk -F'\t' -v w="$2" -v n="$3" '$1=="WORKER" && $2==w{print $n}'; }
key() { printf '%s\n' "$1" | awk -F'\t' -v k="$2" '$1==k{print $2}'; }
has() { grep -qxF -- "$2" <<< "$1"; }
arg() { grep -qxF -- "$2" "$F/$1.args"; }
gone() { ! kill -0 "$(cat "$F/sleep.pid")" 2>/dev/null; }
refused() { local rc=0 out; out=$("$@" 2>"$T/err") || rc=$?; [ "$rc" = 2 ] && [ -z "$(printf '%s\n' "$out" | grep '^WORKER')" ]; }
reset() { rm -f "$F"/*.fail "$F"/*.partial "$F"/*.answer "$F"/*.sleep "$F"/*.empty "$F"/*.ignoreterm "$F/sleep.pid" "$CONF"; }

# Each fake refuses to run without its isolation flags. It records its arguments and the names of
# its environment variables, and answers with what it sees and its prompt.
bin="$T/bin"; mkdir -p "$bin"
cat > "$bin/codex" <<'EOF'
#!/usr/bin/env bash
F="$HOME/fake"
[ "${1:-}" != --version ] || { echo "codex-cli 9.9.9"; exit 0; }
printf '%s\n' "$@" > "$F/codex.args"; env | sed 's/=.*//' | sort > "$F/codex.env"
args=" $* "; o="" c="$PWD" m=none json=""
while [ $# -gt 0 ]; do
  case "$1" in -o) o="$2" ;; -C) c="$2" ;; -m) m="$2" ;; --json) json=1 ;; esac
  shift
done
case "$args" in *" exec -s read-only --ignore-user-config --ephemeral "*) ;;
  *) echo "codex: not isolated: $args" >&2; exit 2 ;; esac
[ ! -f "$F/codex.ignoreterm" ] || trap '' TERM
if [ -f "$F/codex.sleep" ]; then sleep "$(cat "$F/codex.sleep")" & echo $! > "$F/sleep.pid"; wait $!; fi
if [ -f "$F/codex.fail" ]; then [ ! -f "$F/codex.partial" ] || echo "partial codex answer" > "$o"; exit 3; fi
if [ -f "$F/codex.answer" ]; then cat "$F/codex.answer" > "$o"
else { echo FINDING; echo "codex answer in $(cd "$c" && pwd -P)"; echo "codex model: $m, home: ${CODEX_HOME:-unset}"; cat; } > "$o"; fi
[ -z "$json" ] || printf '%s\n' \
  '{"type":"item.completed","item":{"id":"i1","type":"command_execution","command":"ls"}}' \
  '{"type":"item.completed","item":{"id":"i2","type":"mcp_tool_call","server":"arch","tool":"x"}}' \
  '{"type":"item.completed","item":{"id":"i3","type":"agent_message","text":"done"}}' \
  '{"type":"turn.completed","usage":{"input_tokens":1200,"cached_input_tokens":200,"output_tokens":34}}'
EOF
cat > "$bin/claude" <<'EOF'
#!/usr/bin/env bash
F="$HOME/fake"
[ "${1:-}" != --version ] || { echo "9.9.9 (Claude Code)"; exit 0; }
printf '%s\n' "$@" > "$F/claude.args"; env | sed 's/=.*//' | sort > "$F/claude.env"
args=" $* "
case "$args" in *" -p --tools "*" --strict-mcp-config --setting-sources  --no-session-persistence "*) ;;
  *) echo "claude: not isolated: $args" >&2; exit 2 ;; esac
stream=""; case "$args" in *" --output-format stream-json "*) stream=1 ;; esac
[ ! -f "$F/claude.ignoreterm" ] || trap '' TERM
if [ -f "$F/claude.sleep" ]; then sleep "$(cat "$F/claude.sleep")" & echo $! > "$F/sleep.pid"; wait $!; fi
if [ -f "$F/claude.fail" ]; then
  if [ -f "$F/claude.partial" ]; then
    if [ -n "$stream" ]; then echo '{"type":"assistant","message":{"content":[{"type":"text","text":"partial claude answer"}]}}'
    else echo "partial claude answer"; fi
  fi
  exit 3
fi
if [ -f "$F/claude.answer" ]; then answer=$(cat "$F/claude.answer"); else answer=$(printf 'FINDING\nclaude answer in %s\n%s' "$(pwd -P)" "$(cat)"); fi
if [ -n "$stream" ]; then
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}'
  printf '%s' "$answer" | jq -Rsc '{type:"result",subtype:"success",is_error:false,result:.,
    usage:{input_tokens:5,cache_creation_input_tokens:100,cache_read_input_tokens:900,output_tokens:77}}'
else printf '%s\n' "$answer"; fi
EOF
cat > "$bin/opencode" <<'EOF'
#!/usr/bin/env bash
F="$(cd "$(dirname "$0")/.." && pwd -P)/home/fake"
if [ "${1:-}" = --version ]; then
  if [ -f "$F/opencode.versionsleep" ]; then sleep 20 & echo $! > "$F/sleep.pid"; wait $!; fi
  echo 1.18.34; exit 0
fi
printf '%s\n' "$@" > "$F/opencode.args"
env | sed 's/=.*//' | sort > "$F/opencode.env"
printf '%s' "$XDG_DATA_HOME" > "$F/opencode.private"
printf '%s' "$OPENCODE_CONFIG_CONTENT" > "$F/opencode.config.json"
[ "${OPENCODE_DISABLE_PROJECT_CONFIG:-}" = 1 ] && [ "${OPENCODE_DISABLE_CLAUDE_CODE:-}" = 1 ] || exit 2
[ "$HOME" != "$(cd "$F/.." && pwd -P)" ] && [ -L "$XDG_DATA_HOME/opencode/auth.json" ] || exit 2
args=" $* "
case "$args" in *" run --pure --format json --agent polybrief-readonly --dir "*) ;; *) exit 2 ;; esac
cat > "$F/opencode.stdin"
echo 'WARN fake log' >&2
if [ -f "$F/opencode.sleep" ]; then sleep "$(cat "$F/opencode.sleep")" & echo $! > "$F/sleep.pid"; wait $!; fi
[ ! -f "$F/opencode.fail" ] || { echo '{"type":"error","error":{"name":"FakeError"}}'; exit 1; }
[ ! -f "$F/opencode.empty" ] || { echo '{"type":"step_finish","part":{}}'; exit 0; }
[ ! -f "$F/opencode.errorzero" ] || { printf '%s\n' '{"type":"text","part":{"type":"text","text":"FINDING"}}' '{"type":"error","error":{"name":"FakeError"}}'; exit 0; }
printf '%s\n' \
  '{"type":"text","part":{"type":"text","messageID":"m1","text":"Reading the files first."}}' \
  '{"type":"tool_use","part":{"type":"tool","messageID":"m1","tool":"read"}}' \
  '{"type":"step_finish","part":{"messageID":"m1","reason":"tool-calls","tokens":{"input":10,"output":3,"reasoning":2,"cache":{"read":20,"write":4}}}}' \
  '{"type":"text","part":{"type":"text","messageID":"m2","text":"FINDING\nopencode answer"}}' \
  '{"type":"step_finish","part":{"messageID":"m2","reason":"stop"}}'
[ ! -f "$F/opencode.exit3" ] || exit 3
EOF
chmod +x "$bin/codex" "$bin/claude" "$bin/opencode"
ln -s "$(command -v git)" "$bin/git"
PATH="$bin:/usr/bin:/bin"
command -v jq >/dev/null 2>&1 && JQ=yes || JQ=""

g init -q "$T/repo"; cd "$T/repo"
echo one > a.txt; echo 'SECRET=old' > .env; g add .; g commit -qm base
base=$(git rev-parse HEAD)
echo two >> a.txt; g commit -qam change
echo three >> a.txt            # unstaged
echo 'SECRET=new' > .env       # tracked, looks like a secret
echo key > id_rsa; g add id_rsa   # staged, looks like a secret
echo fresh > new.txt           # untracked
echo héllo > café-notes.md      # untracked, a name that git quotes
ln -s nowhere dangling         # untracked, a link that points nowhere
echo TOKEN=1 > .env.local      # untracked, looks like a secret
echo 'x=1' > .envrc            # untracked, looks like a secret
git config diff.noprefix true  # a user setting that changes patch text
printf 'the brief\n' > "$T/brief.md"
before=$(git status --porcelain)
repo=$(pwd -P)
run() { "$S" launch --agents-dir "$A" --dir "$T/repo" --base "$base" --brief "$T/brief.md" "$@"; }
OCM="--set opencode.model=test/model"   # an OpenCode run needs a model

# both workers answer; the prompt carries the brief, the tracked change and the untracked files
export POLYBRIEF_TEST_SECRET=leak   # a variable of the caller that must not reach a worker
out=$(cd "$T" && run --label test/one)
[ "$(printf '%s\n' "$out" | head -1 | cut -f1)" = OUT ] || fail "OUT must be the first line: $out"
[ "$(row "$out" codex)" = ok ] && [ "$(row "$out" claude)" = ok ] || fail "both workers must answer: $out"
! grep -q '^CUT' <<< "$out" || fail "no CUT line without a cut: $out"
d=$(key "$out" OUT)
[ "$(head -1 "$d/prompt.md")" = "the brief" ] || fail "prompt must start from the brief"
grep -q '^+two$' "$d/prompt.md" && grep -q '^+three$' "$d/prompt.md" || fail "prompt must hold committed and unstaged changes"
grep -q '^+fresh$' "$d/prompt.md" || fail "prompt must hold untracked files"
grep -q '^+héllo$' "$d/prompt.md" || fail "prompt must hold untracked files with quoted names"
grep -q '^+++ b/a.txt$' "$d/prompt.md" || fail "the patch text must not depend on the user's diff settings"
grep -q "from $base to the working tree" "$d/prompt.md" || fail "the prompt must name the base commit"
grep -q '^<change-[A-Za-z0-9]\{4,\}>$' "$d/prompt.md" && ! grep -q '^<change>$' "$d/prompt.md" \
  || fail "the change block must use a per-run tag"
grep -q '^Commits of the change:$' "$d/prompt.md" && grep -q ' change$' "$d/prompt.md" || fail "the prompt must hold the history"
tag=$(sed -n 's/^<change-\([A-Za-z0-9]*\)>$/\1/p' "$d/prompt.md")
atag=$(sed -n 's/^<answer-\([A-Za-z0-9]*\) worker="codex" status="ok">$/\1/p' <<< "$out")
[ ${#atag} -ge 8 ] && has "$out" "</answer-$atag>" || fail "answers must be wrapped in a per-run tag: $out"
[ "$atag" != "$tag" ] && ! grep -q -- "$atag" "$d/prompt.md" || fail "a worker must not see the tag of the answer block"
has "$out" "codex answer in $repo" && has "$out" "claude answer in $repo" || fail "workers must run in the reviewed tree: $out"
has "$out" "codex model: test-model, home: $CODEX_HOME" || fail "codex must get the user's top-level model: $out"
arg codex 'model_reasoning_effort="high"' || fail "codex must get the user's top-level effort"
arg codex web_search=disabled || fail "codex must run without web search"
arg codex project_doc_max_bytes=0 || fail "codex must not load the AGENTS.md of the reviewed tree"
[ "$(fld "$out" codex 6)/$(fld "$out" codex 7)/$(fld "$out" codex 8)" = "test-model/high/codex-cli 9.9.9" ] \
  || fail "WORKER line must name model, effort and version: $out"
[ "$(fld "$out" claude 6)" = default ] || fail "claude runs on the CLI default model: $out"
[ "$(git status --porcelain)" = "$before" ] || fail "the reviewed tree must stay untouched"
! grep -q '^## Checklists$' "$d/prompt.md" || fail "no lanes, no checklists"

# a clean environment: the caller's variables stay out, login locations and --env pass
! grep -qx POLYBRIEF_TEST_SECRET "$F/codex.env" && ! grep -qx POLYBRIEF_TEST_SECRET "$F/claude.env" || fail "a caller variable reached a worker"
grep -qx HOME "$F/codex.env" && grep -qx CODEX_HOME "$F/codex.env" && grep -qx PATH "$F/claude.env" || fail "workers need HOME, PATH, CODEX_HOME"
run --workers codex --env POLYBRIEF_TEST_SECRET >/dev/null
grep -qx POLYBRIEF_TEST_SECRET "$F/codex.env" || fail "--env must pass a named variable"

# secret-like files are left out, tracked, staged or untracked; names stay in local diagnostics
for s in .env id_rsa .env.local .envrc; do
  has "$out" "$(printf 'SKIPPED\t%s' "$s")" || fail "secret-like file $s must be reported: $out"
done
! grep -rq 'SECRET=new\|TOKEN=1\|^+key$' "$d/prompt.md" "$d/change.diff" || fail "secret contents must not reach the prompt"
! grep -qE '^- (\.env|id_rsa|\.env.local|\.envrc)$' "$d/prompt.md" \
  && grep -q 'Left out as possible secrets: 4 file(s).' "$d/prompt.md" \
  || fail "the worker prompt must carry counts without secret-like names"

# tool calls come from the JSON events of the CLIs
if [ -n "$JQ" ]; then
  has "$out" "$(printf 'TOOLS\tcodex\tcommand_execution=1 mcp:arch=1')" && has "$out" "$(printf 'TOOLS\tclaude\tRead=1')" \
    || fail "TOOLS lines must count tool calls: $out"
  has "$out" "$(printf 'TOKENS\tcodex\t1200\t34')" && has "$out" "$(printf 'TOKENS\tclaude\t1005\t77')" \
    || fail "TOKENS lines must sum input with cache and output: $out"
  [ "$(awk -F'\t' '$2=="call" && $4=="test/one" && $5=="claude" {print $14 "/" $15}' "$LOG")" = 1005/77 ] \
    || fail "the run log must hold the tokens: $(cat "$LOG")"
fi

# the run log gets one row per worker, and the judge's yield on request
[ "$(awk -F'\t' '$2=="call" && $4=="test/one"' "$LOG" | wc -l | tr -d ' ')" = 2 ] || fail "run log must hold one row per worker"
out2=$("$S" launch --yield R1 --label parallel codex=7/4/2 claude=5/4/2)
has "$out2" "$(printf 'LOGGED\t%s\t2' "$LOG")" && [ "$(awk -F'\t' '$2=="yield" && $3=="R1" && $5=="codex" && $11==7 && $12==4 && $13==2' "$LOG" | wc -l | tr -d ' ')" = 1 ] \
  || fail "--yield must append the yield: $out2"
refused "$S" launch --yield R1 codex=7/x/2 || fail "bad yield counts must be refused"
# launchers of one run write the log at once: one header, whole rows
for i in 1 2 3 4 5 6 7 8; do XDG_STATE_HOME="$T/par" "$S" launch --yield "P$i" a=1/1/1 b=2/2/2 c=3/3/3 d=4/4/4 >/dev/null & done; wait
PL="$T/par/polybrief/polybrief-runs.tsv"
[ "$(grep -c '^time' "$PL")" = 1 ] && [ "$(head -1 "$PL" | cut -f1)" = time ] && [ "$(wc -l < "$PL" | tr -d ' ')" = 33 ] \
  && [ -z "$(awk -F'\t' 'NF!=15' "$PL")" ] || fail "parallel writers must not break the run log: $(cat "$PL")"

# a base given by name reaches the prompt as a commit
out=$("$S" launch --dir "$T/repo" --base HEAD~1 --brief "$T/brief.md" --workers claude)
grep -q "from $base to the working tree" "$(key "$out" OUT)/prompt.md" || fail "a base name must be resolved"

# a model that only a table sets is not the user's model, also when the header is indented
printf '  [profiles.x]\nmodel = "other"\n' > "$CODEX_HOME/config.toml"
out=$(run --workers codex)
has "$out" "codex model: none, home: $CODEX_HOME" || fail "a table's model must not be used: $out"
toml

# settings file: every worker setting, and flags win over it
cat > "$CONF" <<'EOF'
# test settings
codex.model = conf-model
codex.effort = low
codex.web = on
claude.model = sonnet
claude.effort = max
claude.web = on
timeout = 77
secret_names = *.secret
history = off
log = off
EOF
echo 'hidden' > notes.secret
out=$(run)
has "$out" "codex model: conf-model, home: $CODEX_HOME" && arg codex 'model_reasoning_effort="low"' || fail "codex model and effort from settings: $out"
! arg codex web_search=disabled || fail "codex.web = on must allow web search"
arg claude sonnet && arg claude max && arg claude Read,Grep,Glob,WebFetch,WebSearch || fail "claude model, effort and web from settings"
has "$out" "$(printf 'SKIPPED\tnotes.secret')" || fail "secret_names must add names: $out"
! grep -q '^Commits of the change:$' "$(key "$out" OUT)/prompt.md" || fail "history = off must drop the history"
rows=$(wc -l < "$LOG"); run --workers claude >/dev/null; [ "$(wc -l < "$LOG")" = "$rows" ] || fail "log = off must not write"
sc=$("$S" launch --show-config)
has "$sc" "$(printf 'CONFIG\ttimeout\t77\tfile:8')" && has "$sc" "$(printf 'CONFIG_FILE\t%s\tloaded' "$CONF")" \
  && has "$sc" "$(printf 'KNOWN_WORKERS\tcodex claude opencode')" || fail "--show-config must show values and sources: $sc"
sc=$("$S" launch --show-config --timeout 5)
has "$sc" "$(printf 'CONFIG\ttimeout\t5\tflag')" || fail "a flag must win over the settings file: $sc"
sc=$(POLYBRIEF_PATTERNS_DIR="$T/env-patterns" "$S" launch --show-config)
has "$sc" "$(printf 'CONFIG\tpatterns_dir\t%s\tenvironment' "$T/env-patterns")" || fail "environment must override the pattern-directory default"
printf 'patterns_dir = %s\n' "$T/file-patterns" >> "$CONF"
sc=$(POLYBRIEF_PATTERNS_DIR="$T/env-patterns" "$S" launch --show-config)
awk -F'\t' -v expected="$T/file-patterns" '$1=="CONFIG" && $2=="patterns_dir" && $3==expected && $4 ~ /^file:/ {found=1} END{exit !found}' <<< "$sc" \
  || fail "file must override the environment default"
printf 'timeoutt = 5\n' > "$CONF"; refused run || fail "an unknown setting must be refused"
grep -q 'polybrief.conf:1: unknown setting' "$T/err" || fail "the error must name the line"
printf 'codex.web = maybe\n' > "$CONF"; refused run || fail "a bad value must be refused"
printf 'codex.model = a b\n' > "$CONF"; refused run || fail "a model with a space must be refused"
printf 'opencode.model = no-provider\n' > "$CONF"; refused run || fail "an OpenCode model needs provider/model"
printf 'opencode.variant = a b\n' > "$CONF"; refused run || fail "an OpenCode variant with a space must be refused"
printf 'opencode.web = maybe\n' > "$CONF"; refused run || fail "a bad opencode.web value must be refused"
rm "$CONF"; refused run --workers opencode && grep -q 'opencode.model is required' "$T/err" || fail "an OpenCode run without a model must be refused"
printf 'timeout = 1\n' > "$T/repo/inside.conf"
refused run --config "$T/repo/inside.conf" || fail "a settings file inside the reviewed tree must be refused"
rm "$T/repo/inside.conf" notes.secret; reset

# lanes: the runtime's agent files reach the prompt as written, without frontmatter, before the change
first=$(awk 'NR==1 && $0=="---"{fm=1; next} fm && $0=="---"{fm=0; next} !fm && NF{print; exit}' "$A/review-design.md")
out=$(run --lanes review-design,example:review-tests --workers claude)
d=$(key "$out" OUT)
grep -qxF '<checklist name="review-design">' "$d/prompt.md" && grep -qxF '<checklist name="review-tests">' "$d/prompt.md" \
  || fail "each lane must give a checklist"
grep -qxF "$first" "$d/prompt.md" || fail "a checklist must hold the agent's text"
! grep -q '^name: review-design$' "$d/prompt.md" || fail "frontmatter must not reach the prompt"
[ "$(grep -n '^<checklist name="review-design">$' "$d/prompt.md" | cut -d: -f1)" -lt "$(grep -n '^<change-' "$d/prompt.md" | cut -d: -f1)" ] \
  || fail "checklists must come before the change"

# context directories: claude may read them, and the prompt names them
mkdir -p "$T/docs"
out=$(run --workers claude --context-dir "$T/docs")
arg claude --add-dir && arg claude "$T/docs" && grep -qxF -- "- $T/docs" "$(key "$out" OUT)/prompt.md" || fail "a context directory must reach claude and the prompt"
refused run --context-dir "$T/none" || fail "a missing context directory must be refused"

# OpenCode receives the same prompt through an isolated read-only JSON profile.
out=$(run --workers opencode --context-dir "$T/docs" --set opencode.model=anthropic/claude-sonnet-4-5 --set opencode.variant=high)
[ "$(row "$out" opencode)" = ok ] && has "$out" 'opencode answer' || fail "OpenCode answer: $out"
arg opencode --model && arg opencode anthropic/claude-sonnet-4-5 && arg opencode --variant && arg opencode high \
  || fail "OpenCode model and variant must reach the CLI"
[ "$(fld "$out" opencode 7)" = high ] && [ "$(fld "$out" opencode 8)" = 1.18.34 ] || fail "OpenCode variant and version must be reported"
! grep -qx POLYBRIEF_TEST_SECRET "$F/opencode.env" && ! grep -qx OPENCODE_CONFIG "$F/opencode.env" \
  && ! grep -qx CODEX_HOME "$F/opencode.env" && ! grep -qx CLAUDE_CONFIG_DIR "$F/opencode.env" \
  || fail "unsafe environment reached OpenCode"
grep -qx OPENCODE_CONFIG_CONTENT "$F/opencode.env" && grep -Fq '"*":"deny"' "$F/opencode.config.json" \
  && grep -Fq "${T}/docs/**" "$F/opencode.config.json" || fail "OpenCode permission profile or context path is missing"
has "$out" "$(printf 'TOOLS\topencode\tread=1')" && has "$out" "$(printf 'TOKENS\topencode\t34\t5')" \
  || fail "OpenCode tool and token events: $out"
cmp -s "$F/opencode.stdin" "$(key "$out" OUT)/prompt.md" || fail "OpenCode must read the prepared prompt on stdin"
! grep -q 'Reading the files first' "$(key "$out" OUT)/opencode.md" || fail "only the last OpenCode message is the answer"
arg opencode --print-logs && arg opencode --log-level && arg opencode WARN && grep -qx 'WARN fake log' "$(key "$out" OUT)/opencode.log" \
  && ! grep -q 'WARN fake log' "$(key "$out" OUT)/opencode.out" || fail "OpenCode warnings must go to its worker log"
! grep -q webfetch "$F/opencode.config.json" || fail "OpenCode web tools must stay denied by default"
[ "$(git status --porcelain)" = "$before" ] || fail "OpenCode must not change the reviewed tree"
private=$(cat "$F/opencode.private")
[ ! -e "$private" ] || fail "private OpenCode session data must be removed"
run --workers opencode $OCM --set opencode.web=on >/dev/null
grep -Fq '"webfetch":"allow"' "$F/opencode.config.json" && grep -Fq '"websearch":"allow"' "$F/opencode.config.json" \
  || fail "opencode.web=on must allow the web tools"
OPENCODE_API_KEY=zen OPENCODE_CONFIG=unsafe run --workers opencode $OCM --env OPENCODE_API_KEY --env OPENCODE_CONFIG >/dev/null 2>"$T/err"
grep -qx OPENCODE_API_KEY "$F/opencode.env" && ! grep -qx OPENCODE_CONFIG "$F/opencode.env" && grep -q 'opencode ignores env OPENCODE_CONFIG' "$T/err" \
  || fail "a named OpenCode key must pass, and a profile variable must be dropped with a note"
: > "$F/opencode.fail"
rc=0; out=$(run --workers opencode $OCM) || rc=$?
[ "$rc" = 1 ] && [ "$(row "$out" opencode)" = failed ] || fail "OpenCode error events must fail: $out"
rm "$F/opencode.fail"
: > "$F/opencode.empty"
rc=0; out=$(run --workers opencode $OCM) || rc=$?
[ "$rc" = 1 ] && [ "$(row "$out" opencode)" = failed ] || fail "OpenCode without an answer must fail: $out"
rm "$F/opencode.empty"
# an error event with exit 0, and an answer with a nonzero exit, each fail on their own
for mode in errorzero exit3; do
  : > "$F/opencode.$mode"
  rc=0; out=$(run --workers opencode $OCM) || rc=$?
  [ "$rc" = 1 ] && [ "$(row "$out" opencode)" = failed ] || fail "OpenCode $mode must fail: $out"
  rm "$F/opencode.$mode"
done
# a slow OpenCode worker times out, is stopped, and leaves no private directory
echo 20 > "$F/opencode.sleep"; rm -f "$F/sleep.pid"
t0=$SECONDS
out=$(run --workers opencode $OCM --timeout 1) && fail "an OpenCode timeout must exit 1"
[ "$(row "$out" opencode)" = timeout ] && [ $((SECONDS - t0)) -lt 10 ] || fail "a slow OpenCode worker must time out: $out"
sleep 1; gone && [ ! -e "$(cat "$F/opencode.private")" ] || fail "an OpenCode timeout must stop the worker and remove its private directory"
rm "$F/opencode.sleep"
mkdir -p "$T/baddata"; : > "$T/baddata/opencode"
refused env XDG_DATA_HOME="$T/baddata" "$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief.md" --workers opencode $OCM \
  && grep -q 'cannot prepare OpenCode environment' "$T/err" || fail "an OpenCode setup failure must exit 2 before any worker"
# a launcher stopped before the worker starts (here in the version call) removes the private directory itself
rm -f "$F/sleep.pid"; : > "$F/opencode.versionsleep"
"$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief.md" --workers opencode $OCM >/dev/null 2>&1 &
launcher=$!
i=0; while [ ! -s "$F/sleep.pid" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
[ -s "$F/sleep.pid" ] || fail "the OpenCode version call did not start"
kill -TERM "$launcher"; wait "$launcher" 2>/dev/null || true
kill "$(cat "$F/sleep.pid")" 2>/dev/null || true; rm "$F/opencode.versionsleep"
[ -z "$(ls "$TMPDIR" | grep '^polybrief-opencode\.')" ] || fail "a stopped launcher must remove the private OpenCode directory"

# the brief from stdin, one worker
out=$(printf 'stdin brief\n' | "$S" launch --dir "$T/repo" --base "$base" --brief - --workers claude)
[ "$(row "$out" claude)" = ok ] && [ -z "$(row "$out" codex)" ] || fail "--workers must limit the run: $out"
has "$out" 'stdin brief' || fail "brief must be read from stdin"

# an untracked file named "-" is diffed like any other and hides nothing
echo dash > ./-
out=$(run --workers claude)
grep -q '^+dash$' "$(key "$out" OUT)/prompt.md" && grep -q '^+fresh$' "$(key "$out" OUT)/prompt.md" || fail "a file named - must not hide untracked files"
rm ./-

# a change over the size limit is cut, the host is told, and the workers get the file list
head -c 500000 /dev/zero | tr '\0' a > big.txt
out=$(run --workers claude)
d=$(key "$out" OUT)
has "$out" "$(printf 'CUT\t%s\t400000' "$(wc -c < "$d/change.diff" | tr -d ' ')")" || fail "a cut must be reported: $out"
grep -q '^The diff is cut at 400000 bytes' "$d/prompt.md" && grep -qx -- '- big.txt' "$d/prompt.md" || fail "workers must be told about the cut and get the file list"
[ "$(wc -c < "$d/prompt.md")" -lt 410000 ] || fail "a large change must be cut"
rm big.txt

# an answer without the expected lines is malformed; the check can be switched off
printf 'Please run /login\n' > "$F/codex.answer"
rc=0; out=$(run --workers codex) || rc=$?
[ "$rc" = 1 ] && [ "$(row "$out" codex)" = malformed ] && has "$out" 'Please run /login' || fail "a login notice must be malformed: $rc $out"
out=$(run --workers codex --expect '')
[ "$(row "$out" codex)" = ok ] || fail "--expect '' must turn the check off: $out"
printf 'NO FINDINGS  \n' > "$F/codex.answer"   # trailing spaces, as a Markdown line break
out=$(run --workers codex); [ "$(row "$out" codex)" = ok ] || fail "NO FINDINGS is a valid answer: $out"
reset

# a failed worker does not stop the other one, and its partial answer is kept
: > "$F/claude.fail"; : > "$F/claude.partial"
out=$(run)
[ "$(row "$out" claude)" = failed ] && [ "$(row "$out" codex)" = ok ] || fail "one failure must not stop the run: $out"
has "$out" 'partial claude answer' && grep -q '^<answer-[A-Za-z0-9]* worker="claude" status="failed">$' <<< "$out" \
  || fail "a failed worker's answer must be kept: $out"
rc=0; out=$(run --workers claude) || rc=$?
[ "$rc" = 1 ] && [ "$(row "$out" claude)" = failed ] || fail "no answer must exit 1 and report the worker: $rc $out"
reset

# workers start in parallel
echo 2 > "$F/codex.sleep"; echo 2 > "$F/claude.sleep"
t0=$SECONDS; run >/dev/null
[ $((SECONDS - t0)) -lt 4 ] || fail "workers must start in parallel"
reset

# a worker over the time limit is stopped, with the processes it started
echo 20 > "$F/codex.sleep"
t0=$SECONDS
out=$(run --workers codex --timeout 01) && fail "no answer must exit 1"
[ "$(row "$out" codex)" = timeout ] || fail "slow worker must time out: $out"
[ $((SECONDS - t0)) -lt 10 ] || fail "timeout must stop the worker early"
sleep 1; gone || fail "timeout must stop the processes the worker started"

# a worker that ignores TERM is killed after the grace period
: > "$F/codex.ignoreterm"; rm -f "$F/sleep.pid"
t0=$SECONDS
out=$(run --workers codex --timeout 1) || true
[ "$(row "$out" codex)" = timeout ] && [ $((SECONDS - t0)) -lt 12 ] || fail "a TERM-deaf worker must be killed: $((SECONDS - t0))s $out"
sleep 1; gone || fail "a TERM-deaf worker must not survive"
rm "$F/codex.ignoreterm"

# a stopped launcher stops its workers, on TERM and on HUP
for sig in TERM HUP; do
  rm -f "$F/sleep.pid"
  "$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief.md" --workers codex >/dev/null 2>&1 &
  launcher=$!
  i=0; while [ ! -s "$F/sleep.pid" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  [ -s "$F/sleep.pid" ] || fail "the worker did not start"
  kill -"$sig" "$launcher"; wait "$launcher" 2>/dev/null || true
  sleep 1; gone || fail "a launcher stopped by $sig must stop its workers"
done
reset

# tool_log = off: no JSON modes and no TOOLS lines
printf 'tool_log = off\nlog = off\n' > "$CONF"
out=$(run)
! arg codex --json && ! arg claude stream-json && ! printf '%s\n' "$out" | grep -q '^TOOLS\|^TOKENS' || fail "tool_log = off must use text output: $out"
[ "$(row "$out" claude)" = ok ] || fail "claude text output must be the answer: $out"
out=$(run --workers opencode $OCM)
[ "$(row "$out" opencode)" = ok ] && arg opencode json \
  && ! printf '%s\n' "$out" | grep -q '^TOOLS\|^TOKENS' || fail "OpenCode must extract JSON answers with tool_log off: $out"
reset

# the launcher cannot run: exit 2, no WORKER line
refused run --workers gemini || fail "unknown worker must be refused"
refused run --workers codex,codex || fail "a repeated worker must be refused"
refused run --lanes review-cobol || fail "unknown lane must be refused"
refused run --lanes ../README || fail "a lane name must not be a path"
refused run --timeout 0 || fail "a zero timeout must be refused"
refused run --expect '(' || fail "an invalid expect must be refused"
refused "$S" launch --dir "$T/repo" --base nope --brief "$T/brief.md" || fail "unknown base must be refused"
refused "$S" launch --dir "$T" --base "$base" --brief "$T/brief.md" || fail "a non-git directory must be refused"
refused "$S" launch --dir "$T/nowhere" --base "$base" --brief "$T/brief.md" || fail "a missing directory must be refused"
grep -q "no such directory: $T/nowhere" "$T/err" || fail "the error must name the missing directory"
g init -q --bare "$T/bare.git"; g -C "$T/bare.git" fetch -q "$T/repo" main:main
refused "$S" launch --dir "$T/bare.git" --base main --brief "$T/brief.md" && grep -q "not a git work tree" "$T/err" || fail "a bare repository must be refused"
refused env TMPDIR="$T/no-such-tmp" "$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief.md" || fail "a temp directory failure must exit 2"
mkdir -p "$T/repo/tmp"
refused env TMPDIR="$T/repo/tmp" "$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief.md" && grep -q 'temp directory lies inside' "$T/err" \
  && [ -z "$(ls -A "$T/repo/tmp")" ] || fail "a temp directory inside the reviewed tree must be refused"
rmdir "$T/repo/tmp"
# a worker that is not installed
rm "$bin/claude"
! command -v claude >/dev/null 2>&1 || fail "the self-check must not reach a real claude"
out=$(run)
[ "$(row "$out" claude)" = missing ] && [ "$(row "$out" codex)" = ok ] || fail "missing CLI must be reported: $out"
rm "$bin/opencode"
out=$(run --workers codex,opencode $OCM)
[ "$(row "$out" opencode)" = missing ] && [ "$(row "$out" codex)" = ok ] || fail "a missing OpenCode CLI must be reported: $out"

# A non-Git research directory works without a code-review answer contract.
mkdir -p "$T/research"
printf 'research result\n' > "$F/codex.answer"
out=$("$S" launch --dir "$T/research" --brief "$T/brief.md" --workers codex)
[ "$(row "$out" codex)" = ok ] || fail "generic briefs must not require FINDING"
! grep -q '^## The change$' "$(key "$out" OUT)/prompt.md" || fail "generic briefs must not add Git context"
refused "$S" launch --dir "$T/research" --brief "$T/brief.md" --lanes review-design || fail "lanes need caller checklists"

# Preparation is immutable for a run and detects a persistent source change.
context="$T/prepared.json"
"$S" launch --prepare-context "$context" --dir "$T/repo" --base "$base" >/dev/null
"$S" launch --check-context "$context" --dir "$T/repo" || fail "the prepared context must match the source"
mkdir "$T/bad-git"
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bad-git/git"; chmod +x "$T/bad-git/git"
refused env PATH="$T/bad-git:$PATH" "$S" launch --check-context "$context" --dir "$T/repo" \
  && grep -q 'cannot check review context' "$T/err" || fail "a context-check Git error must be an infrastructure failure"
cp "$T/repo/a.txt" "$T/a.saved"
echo drift >> "$T/repo/a.txt"
rc=0; checked=$("$S" launch --check-context "$context" --dir "$T/repo") || rc=$?
[ "$rc" = 1 ] && has "$checked" "$(printf 'DRIFT\t%s' "$(sed -n 's/.*"fingerprint":"\([^"]*\)".*/\1/p' "$context")")" \
  || fail "a source change must invalidate the prepared context: $rc $checked"
cp "$T/a.saved" "$T/repo/a.txt"

# Two binary versions have the same abbreviated Git diff but different bytes.
printf '\000binary-16146' > "$T/repo/binary.dat"
g diff --no-index --no-ext-diff --no-color -- /dev/null binary.dat > "$T/binary-before.diff" || true
"$S" launch --prepare-context "$T/binary-context.json" --dir "$T/repo" --base "$base" >/dev/null
printf '\000binary-17318' > "$T/repo/binary.dat"
g diff --no-index --no-ext-diff --no-color -- /dev/null binary.dat > "$T/binary-after.diff" || true
cmp "$T/binary-before.diff" "$T/binary-after.diff" >/dev/null || fail "binary fixture must have the same printed Git diff"
rc=0; checked=$("$S" launch --check-context "$T/binary-context.json" --dir "$T/repo") || rc=$?
[ "$rc" = 1 ] && grep -q '^DRIFT[[:space:]]' <<< "$checked" || fail "binary content drift must invalidate an unchanged Git diff"
rm "$T/repo/binary.dat"

# A runner sends one prepared Git context to both participants.
reset
out=$("$S" -C "$T/repo" -b "$base" -p twice -w codex "$T/brief.md")
[ "$(key "$out" RESULT)" = complete ] || fail "a clean runner result must be complete: $out"
work=$(key "$out" OUT)
[ -s "$work/change.json" ] || fail "the runner must save one prepared context"
first=$(awk -F'\t' '$1=="OUT"{print $2; exit}' "$work/review/1/codex-1.launch")
second=$(awk -F'\t' '$1=="OUT"{print $2; exit}' "$work/review/1/codex-2.launch")
cmp "$first/change.diff" "$second/change.diff" >/dev/null || fail "participants received different changes"

# The runner marks a result stale when a file changes during worker execution.
echo 2 > "$F/codex.sleep"
"$S" -C "$T/repo" -b "$base" -w codex "$T/brief.md" > "$T/runner.out" 2> "$T/runner.err" & runner=$!
i=0; while [ ! -s "$F/sleep.pid" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
[ -s "$F/sleep.pid" ] || fail "the fake worker did not start for the drift test"
echo drift >> "$T/repo/a.txt"
rc=0; wait "$runner" || rc=$?
[ "$rc" = 1 ] && grep -q '^RESULT[[:space:]]stale[[:space:]]' "$T/runner.out" || fail "a changed source must yield stale: $rc $(cat "$T/runner.out")"
cp "$T/a.saved" "$T/repo/a.txt"; reset

# Read and required artifact errors remain infrastructure failures.
mkdir "$T/brief-dir" "$T/context-dir" "$A/unreadable.md"
refused "$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief-dir" --workers codex \
  && grep -q 'cannot read brief' "$T/err" || fail "an unreadable brief must exit 2"
refused "$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief.md" --agents-dir "$A" --lanes unreadable --workers codex \
  && grep -q 'cannot read checklist' "$T/err" || fail "an unreadable checklist must exit 2"
refused "$S" launch --prepare-context "$T/context-dir" --dir "$T/repo" --base "$base" \
  && grep -q 'cannot write prepared context' "$T/err" || fail "a failed prepared-context write must exit 2"

# Automatic path lists have a fixed bound and report omissions locally.
for i in $(seq 1 110); do printf 'x\n' > "$T/repo/extra-$i.txt"; done
out=$("$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief.md" --workers codex --set max_diff_bytes=1000)
grep -q '^OMITTED[[:space:]]changed-paths[[:space:]]' <<< "$out" || fail "omitted paths must be reported"
rm "$T/repo"/extra-*.txt

# Reject target-local temp paths before invoking even a Git shim that writes there.
mkdir -p "$T/repo/tmp" "$T/git-shim"
cat > "$T/git-shim/git" <<'EOF'
#!/usr/bin/env bash
[ -z "${GIT_PROBE_FILE:-}" ] || touch "$GIT_PROBE_FILE"
touch "$TMPDIR/git-ran"
exec /usr/bin/git "$@"
EOF
chmod +x "$T/git-shim/git"
refused env PATH="$T/git-shim:$PATH" GIT_PROBE_FILE="$T/git-invoked" TMPDIR="$T/no-such-tmp" "$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief.md" \
  && [ ! -e "$T/git-invoked" ] || fail "preflight invoked Git before rejecting a missing TMPDIR"
refused env PATH="$T/git-shim:$PATH" TMPDIR="$T/repo/tmp" "$S" launch --dir "$T/repo" --base "$base" --brief "$T/brief.md" \
  && [ -z "$(ls -A "$T/repo/tmp")" ] || fail "preflight invoked Git before rejecting a target-local TMPDIR"
rmdir "$T/repo/tmp"
echo "ok: all review checks passed"
