// Command polybrief runs one brief on several local agent CLIs, read-only, in the stages of a pattern.
// Contracts: .archcore/runtime/polybrief-cli.spec.md and polybrief-config.spec.md.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime/debug"
	"strings"
	"syscall"
)

// version is set by the release build: -ldflags "-X main.version=X.Y.Z".
var version string

// versionString is the injected version, else the module version of `go install …@vX.Y.Z`, else dev.
func versionString() string {
	if version != "" {
		return version
	}
	if bi, ok := debug.ReadBuildInfo(); ok && bi.Main.Version != "" && bi.Main.Version != "(devel)" {
		return strings.TrimPrefix(bi.Main.Version, "v")
	}
	return "dev"
}

const usage = `Usage:
  polybrief [-C DIR] [-b REF] [-p PATTERN] [-c FILE]... [-w LIST] [-o KEY=VALUE]... [--label TEXT] BRIEF|-
  polybrief plan   [-p PATTERN] [-c FILE]... [-w LIST] [-o KEY=VALUE]...
  polybrief patterns
  polybrief config [-o KEY=VALUE]...
  polybrief yield  [-o KEY=VALUE]... [--label TEXT] RUN NAME=RAISED/KEPT/ONLY...

  BRIEF        task file for every worker; - reads stdin
  -C DIR       working directory (default: current)
  -b REF       Git base: adds the change REF..working tree, untracked files and history
  -p PATTERN   built-in pattern name or .md file (default: parallel)
  -c FILE      checklist file, repeatable; a pattern names it by file name without .md
  -w LIST      workers of this run: codex, claude, opencode (default: codex,claude)
  -o KEY=VALUE one setting, repeatable (codex.effort=high, timeout=1800, ...; see config)
  --label TEXT  run label in the run log (default: pattern name)

Output: tab-separated lines. OUT is the folder with every prompt, answer and log;
CALLS is planned calls and the call limit; one WORKER line per answer (status, path);
RESULT is complete, partial, stale or failed. Every answer then follows in full,
between <answer-...> tags. Problems go to stderr.
Exit: 0 every executed stage has an ok answer; 1 stale, no stage answer or call limit;
2 polybrief could not prepare, read or write a required file; 143 stopped by a signal.
`

func main() {
	args := os.Args[1:]
	if len(args) > 0 {
		switch args[0] {
		case "launch":
			os.Exit(launchMain(args[1:]))
		case "runner":
			os.Exit(runnerMain(args[1:]))
		case "plan", "patterns", "config", "yield":
			os.Exit(public(args[0], args[1:]))
		case "--version", "version":
			fmt.Println("polybrief " + versionString())
			return
		case "-h", "--help", "help":
			fmt.Print(usage)
			return
		}
	}
	if len(args) == 0 {
		fmt.Print(usage)
		return
	}
	os.Exit(public("run", args))
}

// public maps the public command line onto the runner and the launcher.
func public(cmd string, args []string) int {
	dir, base, pattern, workers, label := ".", "", "", "", ""
	var checklists, sets, pos []string
	allowed := map[string]string{
		"run": "-C -b -p -c -w -o --label", "plan": "-p -c -w -o",
		"patterns": "", "config": "-o", "yield": "-o --label",
	}[cmd]
	for i := 0; i < len(args); i++ {
		f := args[i]
		if !strings.HasPrefix(f, "-") || f == "-" {
			pos = append(pos, args[i:]...)
			break
		}
		if f == "-h" || f == "--help" {
			fmt.Print(usage)
			return 0
		}
		if !contains(strings.Fields(allowed), f) {
			die(fmt.Sprintf("unknown flag '%s' for %s", f, cmd))
		}
		if i+1 >= len(args) {
			die(f + " needs a value")
		}
		v := args[i+1]
		i++
		switch f {
		case "-C":
			dir = v
		case "-b":
			base = v
		case "-p":
			pattern = v
		case "-c":
			checklists = append(checklists, v)
		case "-w":
			if strings.TrimSpace(v) == "" {
				die("-w needs at least one worker: codex, claude, opencode")
			}
			workers = v
		case "-o":
			sets = append(sets, v)
		case "--label":
			label = v
		}
	}
	var common []string
	if cmd == "run" {
		root, err := filepath.Abs(dir)
		if err != nil {
			die("cannot resolve directory: " + err.Error())
		}
		tmp := os.TempDir()
		tmpInfo, err := os.Stat(tmp)
		if err != nil || !tmpInfo.IsDir() {
			die("cannot use temp directory: " + tmp)
		}
		if inside(physical(tmp), physical(root)) {
			die("the temp directory lies inside the reviewed tree: " + physical(tmp))
		}
	}
	for _, s := range sets {
		if !strings.Contains(s, "=") {
			die(fmt.Sprintf("bad override '%s' (use KEY=VALUE)", s))
		}
		common = append(common, "--set", s)
	}
	self, _ := os.Executable()

	switch cmd {
	case "config":
		if len(pos) > 0 {
			die("config takes no arguments")
		}
		return passthrough(exec.Command(self, append([]string{"launch", "--show-config"}, common...)...))
	case "yield":
		if len(pos) < 2 {
			die("yield needs RUN and NAME=RAISED/KEPT/ONLY")
		}
		a := append([]string{"launch", "--yield", pos[0]}, pos[1:]...)
		if label != "" {
			a = append(a, "--label", label)
		}
		return passthrough(exec.Command(self, append(a, common...)...))
	case "patterns":
		if len(pos) > 0 {
			die("patterns takes no arguments")
		}
		return passthrough(exec.Command(self, append([]string{"runner", "--list"}, common...)...))
	}

	a := []string{"runner"}
	if cmd == "plan" {
		if len(pos) > 0 {
			die("plan takes no arguments")
		}
		a = append(a, "--check")
	} else {
		if len(pos) != 1 {
			die("a run needs one BRIEF (a file, or - for stdin)")
		}
		a = append(a, "--dir", dir, "--brief", pos[0])
		if base != "" {
			a = append(a, "--base", base)
		}
	}
	if pattern != "" {
		a = append(a, "--pattern", pattern)
	}
	if label != "" {
		a = append(a, "--label", label)
	}
	if workers != "" {
		a = append(a, "--clients", workers)
	}
	if len(checklists) > 0 {
		cdir, names := checklistDir(checklists)
		defer os.RemoveAll(cdir)
		a = append(a, "--agents-dir", cdir, "--lanes", strings.Join(names, ","))
	}
	return passthrough(exec.Command(self, append(a, common...)...))
}

// checklistDir links the -c files into one temporary directory, named by file name without .md.
func checklistDir(files []string) (string, []string) {
	dir, err := os.MkdirTemp(os.TempDir(), "polybrief-checklists.")
	if err != nil {
		die("cannot create a temp directory")
	}
	var names []string
	for _, f := range files {
		abs, _ := filepath.Abs(f)
		if st, err := os.Stat(abs); err != nil || st.IsDir() {
			os.RemoveAll(dir)
			die("no such checklist: " + f)
		}
		name := strings.TrimSuffix(filepath.Base(abs), ".md")
		if !nameChars.MatchString(name) {
			os.RemoveAll(dir)
			die(fmt.Sprintf("bad checklist name '%s' (use a-z, 0-9 and -)", name))
		}
		if contains(names, name) {
			os.RemoveAll(dir)
			die(fmt.Sprintf("two checklists named '%s'", name))
		}
		place(dir, abs, name)
		names = append(names, name)
	}
	return dir, names
}

// place links a checklist into dir as NAME.md.
func place(dir, src, name string) {
	link := filepath.Join(dir, name+".md")
	if os.Symlink(src, link) != nil {
		// Windows without Developer Mode cannot create symlinks; a copy reads the same.
		data, err := os.ReadFile(src)
		if err != nil || os.WriteFile(link, data, 0o600) != nil {
			os.RemoveAll(dir)
			die("cannot place checklist: " + src)
		}
	}
}

// passthrough runs a child with this process's stdio, forwards stop signals, and returns its exit code.
func passthrough(c *exec.Cmd) int {
	c.Stdin, c.Stdout, c.Stderr = os.Stdin, os.Stdout, os.Stderr
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGTERM, syscall.SIGINT, syscall.SIGHUP)
	if err := c.Start(); err != nil {
		die(err.Error())
	}
	go func() {
		for s := range sigs {
			c.Process.Signal(s)
		}
	}()
	err := c.Wait()
	if ee, ok := err.(*exec.ExitError); ok {
		if code := ee.ExitCode(); code >= 0 {
			return code
		}
		return 143
	}
	return 0
}
