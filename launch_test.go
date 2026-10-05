package main

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestBoundedHistoryReportsOmittedLines(t *testing.T) {
	history := strings.Repeat("x\n", 9000)
	got, omitted := boundedHistory(history)
	if len(got) != 16000 || omitted != 1000 {
		t.Fatalf("history limit: got %d bytes and %d omitted lines, want 16000 and 1000", len(got), omitted)
	}
	if got != strings.Repeat("x\n", 8000) {
		t.Fatal("history was cut inside a line")
	}
}

func TestOpenCodeEvents(t *testing.T) {
	raw := []byte(`{"type":"text","part":{"type":"text","messageID":"m1","text":"I will read the files first."}}
{"type":"tool_use","part":{"type":"tool","messageID":"m1","tool":"read"}}
{"type":"tool_use","part":{"type":"tool","messageID":"m1","tool":""}}
{"type":"step_finish","part":{"tokens":{"input":10,"output":3,"reasoning":2,"cache":{"read":20,"write":4}}}}
{"type":"tool_use","part":{"type":"tool","messageID":"m2","tool":"read"}}
{"type":"tool_use","part":{"type":"tool","messageID":"m2","tool":"grep"}}
{"type":"step_finish","part":{"tokens":{"input":1,"output":1,"reasoning":0,"cache":{"read":0,"write":0}}}}
{"type":"text","part":{"type":"reasoning","messageID":"m2","text":"hidden"}}
{"type":"text","part":{"type":"text","messageID":"m2","text":"FINDING\nfirst"}}
not json
{"type":"text","part":{"type":"text","messageID":"m2","text":"second\n"}}
`)
	answer, bad := openCodeAnswer(raw)
	if bad || answer != "FINDING\nfirst\nsecond\n" {
		t.Fatalf("only the last message's text must be the answer: %q, bad %v", answer, bad)
	}
	if answer, _ := openCodeAnswer([]byte(`{"type":"text","part":{"type":"text","text":"a"}}
{"type":"text","part":{"type":"text","text":"b"}}`)); answer != "a\nb\n" {
		t.Fatalf("text without message IDs must be joined: %q", answer)
	}
	if got := toolsOf("opencode", raw); got != "grep=1 read=2" {
		t.Fatalf("tool calls must add up over steps: %q", got)
	}
	in, out, ok := tokensOf("opencode", raw)
	if !ok || in != 35 || out != 6 {
		t.Fatalf("tokens %d/%d, ok %v", in, out, ok)
	}
	if _, _, ok := tokensOf("opencode", []byte(`{"type":"step_finish","part":{}}`)); ok {
		t.Fatal("a step without tokens must not report usage")
	}
	if answer, bad := openCodeAnswer(nil); answer != "" || bad {
		t.Fatalf("an empty stream must give no answer: %q, bad %v", answer, bad)
	}
	if _, bad := openCodeAnswer([]byte(`{"type":"text","part":{"type":"text","text":"FINDING"}}
{"type":"error","error":{"name":"ProviderError"}}`)); !bad {
		t.Fatal("an error event must fail the worker")
	}

	// The last step decides: it must hold text and end normally.
	narration := `{"type":"text","part":{"type":"text","messageID":"m1","text":"I will read the files first."}}
{"type":"step_finish","part":{"messageID":"m1","reason":"tool-calls"}}
`
	if answer, bad := openCodeAnswer([]byte(narration + `{"type":"text","part":{"type":"text","messageID":"m2","text":"FINDING"}}
{"type":"step_finish","part":{"messageID":"m2","reason":"stop"}}`)); answer != "FINDING\n" || bad {
		t.Fatalf("a normal last step must be the answer: %q, bad %v", answer, bad)
	}
	if answer, _ := openCodeAnswer([]byte(narration + `{"type":"text","part":{"type":"reasoning","messageID":"m2","text":"thinking"}}
{"type":"step_finish","part":{"messageID":"m2","reason":"stop"}}`)); answer != "" {
		t.Fatalf("a last step without text must give no answer, not the narration: %q", answer)
	}
	for _, reason := range []string{"length", "tool-calls", "unknown"} {
		if _, bad := openCodeAnswer([]byte(narration + `{"type":"text","part":{"type":"text","messageID":"m2","text":"FINDING"}}
{"type":"step_finish","part":{"messageID":"m2","reason":"` + reason + `"}}`)); !bad {
			t.Fatalf("a last step that ended on %s must fail the worker", reason)
		}
	}
}

func TestOpenCodeEnvironment(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	auth := filepath.Join(home, "data", "opencode", "auth.json")
	if err := os.MkdirAll(filepath.Dir(auth), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(auth, []byte(`{"provider":{"key":"secret"}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	ctx := filepath.Join(home, "docs")
	tmpRoot := t.TempDir()
	env, cleanup, err := openCodeEnvironment([]string{"PATH=/bin", "HOME=/original", "TMPDIR=/original", "CODEX_HOME=/codex", "CLAUDE_CONFIG_DIR=/claude",
		"XDG_CONFIG_HOME=/original", "XDG_CONFIG_DIRS=/etc/xdg", "OPENCODE_CONFIG=unsafe", "OPENCODE_PERMISSION=unsafe", "OPENCODE_API_KEY=zen", "OPENCODE_ENABLE_EXA=1", "OPENCODE_ENABLE_PARALLEL=1", "API_KEY=allowed"}, tmpRoot, false, []string{ctx})
	if err != nil {
		t.Fatal(err)
	}
	values := map[string]string{}
	for _, entry := range env {
		k, v, _ := strings.Cut(entry, "=")
		if _, seen := values[k]; seen {
			t.Fatalf("%s is set twice: %v", k, env)
		}
		values[k] = v
	}
	if values["API_KEY"] != "allowed" || values["OPENCODE_API_KEY"] != "zen" || values["OPENCODE_ENABLE_EXA"] != "1" || values["OPENCODE_ENABLE_PARALLEL"] != "1" ||
		values["OPENCODE_DISABLE_PROJECT_CONFIG"] != "1" || values["OPENCODE_DISABLE_CLAUDE_CODE"] != "1" {
		t.Fatalf("environment keys: %v", env)
	}
	for _, k := range []string{"CODEX_HOME", "CLAUDE_CONFIG_DIR", "XDG_CONFIG_DIRS", "OPENCODE_CONFIG", "OPENCODE_PERMISSION", "OPENCODE_DISABLE_DEFAULT_PLUGINS"} {
		if _, ok := values[k]; ok {
			t.Fatalf("%s must not reach OpenCode: %v", k, env)
		}
	}
	root := filepath.Dir(values["HOME"])
	if filepath.Dir(root) != tmpRoot {
		t.Fatalf("the private root %q must lie in %q", root, tmpRoot)
	}
	for k, sub := range map[string]string{"HOME": "home", "TMPDIR": "tmp", "XDG_CONFIG_HOME": "config", "XDG_DATA_HOME": "data", "XDG_CACHE_HOME": "cache", "XDG_STATE_HOME": "state"} {
		if values[k] != filepath.Join(root, sub) {
			t.Fatalf("%s = %q, want %q", k, values[k], filepath.Join(root, sub))
		}
	}
	data := filepath.Join(values["XDG_DATA_HOME"], "opencode", "auth.json")
	if link, err := os.Readlink(data); err != nil || link != auth {
		t.Fatalf("auth link %q: %v", link, err)
	}
	// The exact profile: any added allow, such as edit or task, must fail here.
	readOnly := map[string]any{"*": "deny", "glob": "allow", "grep": "allow", "list": "allow",
		"read": map[string]any{"*": "allow", "*.env": "deny", "*.env.*": "deny", "*.env.example": "allow"}}
	want := map[string]any{"external_directory": map[string]any{ctx: "allow", filepath.Join(ctx, "**"): "allow"}}
	for k, v := range readOnly {
		want[k] = v
	}
	openCodeProfileIs(t, env, want)
	cleanup()
	cleanup()
	if _, err := os.Lstat(root); !os.IsNotExist(err) {
		t.Fatalf("private data remained: %v", err)
	}
	webEnv, webCleanup, err := openCodeEnvironment(nil, t.TempDir(), true, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer webCleanup()
	want = map[string]any{"webfetch": "allow", "websearch": "allow"}
	for k, v := range readOnly {
		want[k] = v
	}
	openCodeProfileIs(t, webEnv, want)

	// An unreadable login location stops the setup and leaves nothing behind.
	bad := t.TempDir()
	if err := os.WriteFile(filepath.Join(bad, "opencode"), nil, 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_DATA_HOME", bad)
	failRoot := t.TempDir()
	if _, _, err := openCodeEnvironment(nil, failRoot, false, nil); err == nil {
		t.Fatal("a broken login location must fail the setup")
	}
	if left, _ := os.ReadDir(failRoot); len(left) != 0 {
		t.Fatalf("a failed setup left %v", left)
	}

	// Without an absolute HOME there is no login to link.
	t.Setenv("XDG_DATA_HOME", "relative")
	t.Setenv("HOME", "")
	relEnv, relCleanup, err := openCodeEnvironment(nil, t.TempDir(), false, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer relCleanup()
	for _, entry := range relEnv {
		if v, ok := strings.CutPrefix(entry, "XDG_DATA_HOME="); ok {
			if _, err := os.Lstat(filepath.Join(v, "opencode", "auth.json")); !os.IsNotExist(err) {
				t.Fatalf("a relative login path must not be linked: %v", err)
			}
		}
	}
}

// openCodeProfileIs checks that the top-level and the agent permission both equal want.
func openCodeProfileIs(t *testing.T, env []string, want map[string]any) {
	t.Helper()
	var config struct {
		Permission map[string]any `json:"permission"`
		Agent      map[string]struct {
			Permission map[string]any `json:"permission"`
		} `json:"agent"`
	}
	for _, entry := range env {
		if v, ok := strings.CutPrefix(entry, "OPENCODE_CONFIG_CONTENT="); ok {
			if err := json.Unmarshal([]byte(v), &config); err != nil {
				t.Fatal(err)
			}
		}
	}
	if !reflect.DeepEqual(config.Permission, want) || !reflect.DeepEqual(config.Agent["polybrief-readonly"].Permission, want) {
		t.Fatalf("permission profile\n top:   %v\n agent: %v\n want:  %v", config.Permission, config.Agent["polybrief-readonly"].Permission, want)
	}
}

func TestInstalledOpenCodeProfile(t *testing.T) {
	if os.Getenv("POLYBRIEF_TEST_REAL_OPENCODE") != "1" {
		t.Skip("set POLYBRIEF_TEST_REAL_OPENCODE=1 for the installed CLI config probe")
	}
	if _, err := exec.LookPath("opencode"); err != nil {
		t.Skip("opencode is not installed")
	}
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	project := t.TempDir()
	if err := os.WriteFile(filepath.Join(project, "opencode.json"), []byte(`{"model":"sentinel/should-not-load"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	env, cleanup, err := openCodeEnvironment([]string{"PATH=" + os.Getenv("PATH")}, t.TempDir(), false, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "opencode", "--pure", "debug", "config")
	cmd.Env, cmd.Dir = env, project
	data, err := cmd.Output()
	if err != nil {
		t.Fatalf("opencode debug config: %v", err)
	}
	var config map[string]any
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatal(err)
	}
	if config["model"] == "sentinel/should-not-load" {
		t.Fatal("project config reached OpenCode")
	}
	if mcp, ok := config["mcp"].(map[string]any); ok && len(mcp) != 0 {
		t.Fatalf("MCP config reached OpenCode: %v", mcp)
	}
	if plugins, ok := config["plugin"].([]any); ok && len(plugins) != 0 {
		t.Fatalf("external plugins reached OpenCode: %v", plugins)
	}
	permission, ok := config["permission"].(map[string]any)
	read, _ := permission["read"].(map[string]any)
	if !ok || permission["*"] != "deny" || read["*"] != "allow" || read["*.env"] != "deny" || permission["bash"] != nil {
		t.Fatalf("unexpected effective permissions: %v", permission)
	}
}
