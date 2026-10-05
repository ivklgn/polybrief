package main

import (
	"os/exec"
	"strconv"
)

// newGroup is a no-op: taskkill /T follows the parent-child tree instead of a process group.
func newGroup(c *exec.Cmd) {}

// stopGroup kills a process and its children.
// ponytail: no grace period like TERM then KILL; add a Job object with CTRL_BREAK if answers get cut.
func stopGroup(pid int) { exec.Command("taskkill", "/T", "/F", "/PID", strconv.Itoa(pid)).Run() }

// stopChild kills a child polybrief process with its workers; Windows cannot deliver TERM to it.
func stopChild(c *exec.Cmd) { stopGroup(c.Process.Pid) }
