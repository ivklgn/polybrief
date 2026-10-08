package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestArgumentSettingsAndCodexDefaults(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	if err := os.MkdirAll(filepath.Join(home, ".codex"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ".codex/config.toml"),
		[]byte("model = \"toml-model\"\nmodel_reasoning_effort = 'low'\n[profiles.x]\nmodel = \"other\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	s := newSettings()
	s.setFlag("claude.effort=max")
	s.setFlag("timeout=70")
	s.setFlag("opencode.model=anthropic/claude-sonnet-4-5")
	s.validate()

	want := map[string][2]string{
		"timeout":        {"70", "flag"},
		"claude.effort":  {"max", "flag"},
		"codex.model":    {"toml-model", "codex-config"},
		"codex.effort":   {"low", "codex-config"},
		"opencode.model": {"anthropic/claude-sonnet-4-5", "flag"},
		"workers":        {"codex,claude", "default"},
	}
	for k, w := range want {
		if s.get(k) != w[0] || s.source(k) != w[1] {
			t.Errorf("%s = %q (%s), want %q (%s)", k, s.get(k), s.source(k), w[0], w[1])
		}
	}
}

// TestValidateRefuses runs validate in a child process, because a bad value exits 2.
func TestValidateRefuses(t *testing.T) {
	if kv := os.Getenv("POLYBRIEF_TEST_SET"); kv != "" {
		s := newSettings()
		s.setFlag(kv)
		s.validate()
		os.Exit(0)
	}
	for _, kv := range []string{"timeout=99999999999", "timeout=0", "secret_names=[", "nope=1", "workers=codex", "timeout"} {
		c := exec.Command(os.Args[0], "-test.run=TestValidateRefuses")
		c.Env = append(os.Environ(), "POLYBRIEF_TEST_SET="+kv, "HOME="+t.TempDir())
		if err := c.Run(); err == nil {
			t.Errorf("%s must be refused", kv)
		}
	}
}
