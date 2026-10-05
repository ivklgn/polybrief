package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var settingKeys = []string{
	"workers", "timeout", "expect", "codex.model", "codex.effort", "codex.web",
	"claude.model", "claude.effort", "claude.web", "opencode.model", "opencode.variant", "opencode.web",
	"env", "context_dirs", "secret_names",
	"max_diff_bytes", "history", "tool_log", "log", "patterns_dir", "pattern", "max_calls",
}

var knownWorkers = []string{"codex", "claude", "opencode"}

var effortValues = map[string][]string{
	"codex":  {"minimal", "low", "medium", "high", "xhigh"},
	"claude": {"low", "medium", "high", "xhigh", "max"},
}

type setting struct{ val, src string }

// settings holds every key with its value and the source that set it.
type settings struct {
	m     map[string]*setting
	file  string
	state string // loaded | absent
}

func isKey(k string) bool { return contains(settingKeys, k) }

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

func newSettings() *settings {
	s := &settings{m: map[string]*setting{}}
	for _, k := range settingKeys {
		s.m[k] = &setting{"", "default"}
	}
	home := homeDir()
	cfgHome := envOr("XDG_CONFIG_HOME", filepath.Join(home, ".config")) + "/polybrief"
	s.def("workers", "codex,claude")
	s.def("timeout", "900")
	s.def("codex.web", "off")
	s.def("claude.web", "off")
	s.def("opencode.web", "off")
	s.def("max_diff_bytes", "400000")
	s.def("history", "on")
	s.def("tool_log", "on")
	s.def("log", envOr("XDG_STATE_HOME", filepath.Join(home, ".local/state"))+"/polybrief/polybrief-runs.tsv")
	s.def("patterns_dir", cfgHome+"/patterns")
	if v := os.Getenv("POLYBRIEF_PATTERNS_DIR"); v != "" {
		s.set("patterns_dir", v, "environment")
	}
	s.def("pattern", "parallel")
	s.def("max_calls", "12")
	return s
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func (s *settings) def(k, v string)        { s.m[k].val = v }
func (s *settings) set(k, v, src string)   { s.m[k] = &setting{v, src} }
func (s *settings) get(k string) string    { return s.m[k].val }
func (s *settings) source(k string) string { return s.m[k].src }

// setFlag applies one KEY=VALUE override with the source `flag`.
func (s *settings) setFlag(kv string) {
	k, v, ok := strings.Cut(kv, "=")
	k = strings.TrimSpace(k)
	if !ok {
		die(fmt.Sprintf("bad override '%s' (use KEY=VALUE)", kv))
	}
	if !isKey(k) {
		die(fmt.Sprintf("unknown setting '%s'", k))
	}
	s.set(k, strings.TrimSpace(v), "flag")
}

// load reads the settings file. Flags set before stay; an empty value keeps the default.
func (s *settings) load(explicit string) {
	cfgHome := envOr("XDG_CONFIG_HOME", filepath.Join(homeDir(), ".config")) + "/polybrief"
	s.file = explicit
	if s.file == "" {
		s.file = os.Getenv("POLYBRIEF_CONFIG")
	}
	named := s.file != ""
	if !named {
		s.file = cfgHome + "/polybrief.conf"
	}
	s.state = "absent"
	f, err := os.Open(s.file)
	if err != nil {
		if named {
			die("no such settings file: " + s.file)
		}
		return
	}
	defer f.Close()
	s.state = "loaded"
	section, n := "", 0
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		n++
		line := strings.TrimSpace(sc.Text())
		at := fmt.Sprintf("%s:%d", s.file, n)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.TrimSpace(line[1 : len(line)-1])
			if !contains(knownWorkers, section) {
				die(fmt.Sprintf("%s: unknown section '[%s]' (known: %s)", at, section, strings.Join(knownWorkers, ", ")))
			}
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			die(at + ": expected 'key = value'")
		}
		k, v = strings.TrimSpace(k), strings.TrimSpace(v)
		if section != "" {
			if strings.Contains(k, ".") {
				die(fmt.Sprintf("%s: dotted key '%s' inside [%s]", at, k, section))
			}
			k = section + "." + k
		}
		if !isKey(k) {
			die(fmt.Sprintf("%s: unknown setting '%s'", at, k))
		}
		if k == "expect" {
			fmt.Fprintln(os.Stderr, "polybrief: ignored setting expect")
			continue
		}
		if v == "" || s.source(k) == "flag" {
			continue
		}
		s.set(k, v, "file:"+strconv.Itoa(n))
	}
}

var modelChars = regexp.MustCompile(`^[A-Za-z0-9._:/-]*$`)
var nameChars = regexp.MustCompile(`^[a-z0-9-]+$`)
var envName = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)

func isInt(s string) bool {
	if s == "" {
		return false
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

func atoi(s string) int { n, _ := strconv.Atoi(s); return n }

// validate checks every value and normalizes numbers and paths. Errors exit 2.
func (s *settings) validate() {
	bad := func(k, why string) { die(fmt.Sprintf("setting %s (%s): %s", k, s.source(k), why)) }
	for _, k := range []string{"timeout", "max_diff_bytes", "max_calls"} {
		if !isInt(s.get(k)) {
			bad(k, "needs a whole number")
		}
		s.m[k].val = strconv.Itoa(atoi(s.get(k)))
	}
	if atoi(s.get("timeout")) < 1 {
		bad("timeout", "needs at least one second")
	}
	if atoi(s.get("max_diff_bytes")) < 1000 {
		bad("max_diff_bytes", "needs at least 1000")
	}
	if m := atoi(s.get("max_calls")); m < 1 || m > 40 {
		bad("max_calls", "must be 1 to 40")
	}
	for _, k := range []string{"codex.web", "claude.web", "opencode.web", "history", "tool_log"} {
		if v := s.get(k); v != "on" && v != "off" {
			bad(k, "must be on or off")
		}
	}
	for _, w := range knownWorkers {
		if !modelChars.MatchString(s.get(w + ".model")) {
			bad(w+".model", "holds characters outside A-Z a-z 0-9 . _ : / -")
		}
	}
	if m := s.get("opencode.model"); m != "" {
		provider, model, found := strings.Cut(m, "/")
		if !found || provider == "" || model == "" {
			bad("opencode.model", "must be provider/model")
		}
	}
	if !modelChars.MatchString(s.get("opencode.variant")) {
		bad("opencode.variant", "holds characters outside A-Z a-z 0-9 . _ : / -")
	}
	for _, w := range []string{"codex", "claude"} {
		if e := s.get(w + ".effort"); e != "" && !contains(effortValues[w], e) {
			bad(w+".effort", fmt.Sprintf("'%s' is not one of %s", e, strings.Join(effortValues[w], ", ")))
		}
	}
	if !nameChars.MatchString(s.get("pattern")) {
		bad("pattern", "must be a name of a-z, 0-9 and -")
	}
	if e := s.get("expect"); e != "" {
		if _, err := regexp.Compile(e); err != nil {
			bad("expect", "is not a valid extended regular expression")
		}
	}
	for _, k := range []string{"log", "patterns_dir"} {
		if s.get(k) != "off" {
			s.m[k].val = homePath(s.get(k))
		}
	}
	if s.get("patterns_dir") == "off" {
		bad("patterns_dir", "cannot be off")
	}
	ws := items(s.get("workers"))
	if len(ws) == 0 {
		bad("workers", "is empty")
	}
	seen := map[string]bool{}
	for _, w := range ws {
		if !contains(knownWorkers, w) {
			bad("workers", fmt.Sprintf("unknown worker '%s' (known: %s)", w, strings.Join(knownWorkers, " ")))
		}
		if seen[w] {
			bad("workers", fmt.Sprintf("names '%s' twice", w))
		}
		seen[w] = true
	}
	s.codexDefaults()
}

// codexDefaults takes the Codex model and effort from the top level of config.toml when unset.
// ponytail: top-level `key = "value"` or 'value' lines only; set codex.model for anything else.
func (s *settings) codexDefaults() {
	home := envOr("CODEX_HOME", filepath.Join(homeDir(), ".codex"))
	data, err := os.ReadFile(filepath.Join(home, "config.toml"))
	if err != nil {
		return
	}
	re := map[string]*regexp.Regexp{
		"codex.model":  regexp.MustCompile(`^model *= *["']([^"']*)["']`),
		"codex.effort": regexp.MustCompile(`^model_reasoning_effort *= *["']([^"']*)["']`),
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "[") {
			break
		}
		for k, r := range re {
			if m := r.FindStringSubmatch(line); m != nil && s.get(k) == "" && m[1] != "" {
				s.set(k, m[1], "codex-config")
			}
		}
	}
}

// homeDir is $HOME, else the OS home directory (%USERPROFILE% on Windows).
func homeDir() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	h, _ := os.UserHomeDir()
	return h
}

func homePath(p string) string {
	home := homeDir()
	if p == "~" {
		return home
	}
	if strings.HasPrefix(p, "~/") {
		return home + "/" + p[2:]
	}
	return p
}

// items splits a comma-separated list into trimmed, non-empty items.
func items(s string) []string {
	var out []string
	for _, x := range strings.Split(s, ",") {
		if x = strings.TrimSpace(x); x != "" {
			out = append(out, x)
		}
	}
	return out
}

func die(msg string) {
	fmt.Fprintln(os.Stderr, "polybrief: "+msg)
	os.Exit(2)
}
