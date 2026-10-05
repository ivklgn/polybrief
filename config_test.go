package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSettingsFile(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("POLYBRIEF_CONFIG", "")
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	os.MkdirAll(filepath.Join(home, ".codex"), 0o755)
	os.WriteFile(filepath.Join(home, ".codex/config.toml"),
		[]byte("model = \"toml-model\"\nmodel_reasoning_effort = 'low'\n[profiles.x]\nmodel = \"other\"\n"), 0o644)
	file := filepath.Join(home, "polybrief.conf")
	os.WriteFile(file, []byte(`# comment
timeout = 60
claude.model = opus
timeout = 70
history =

[codex]
effort = high

[claude]
effort = max

[opencode]
model = anthropic/claude-sonnet-4-5
variant = high
web = on
`), 0o644)

	s := newSettings()
	s.setFlag("claude.effort=low")
	s.load(file)
	s.validate()

	want := map[string][2]string{
		"timeout":          {"70", "file:4"},               // the later line wins
		"history":          {"on", "default"},              // an empty value keeps the default
		"codex.effort":     {"high", "file:8"},             // a section key is the dotted key
		"claude.model":     {"opus", "file:3"},             // the dotted form still works
		"claude.effort":    {"low", "flag"},                // a flag wins over the file
		"codex.model":      {"toml-model", "codex-config"}, // top level of config.toml only
		"opencode.model":   {"anthropic/claude-sonnet-4-5", "file:14"},
		"opencode.variant": {"high", "file:15"},
		"opencode.web":     {"on", "file:16"},
	}
	for k, w := range want {
		if s.get(k) != w[0] || s.source(k) != w[1] {
			t.Errorf("%s = %q (%s), want %q (%s)", k, s.get(k), s.source(k), w[0], w[1])
		}
	}
	if s.state != "loaded" {
		t.Errorf("state %q", s.state)
	}
}

func TestAbsentDefaultFile(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("POLYBRIEF_CONFIG", "")
	s := newSettings()
	s.load("")
	s.validate()
	if s.state != "absent" || s.get("pattern") != "parallel" || s.get("workers") != "codex,claude" {
		t.Errorf("defaults: %q %q %q", s.state, s.get("pattern"), s.get("workers"))
	}
}
