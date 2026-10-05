//go:build !windows

package main

import (
	"os/exec"
	"syscall"
	"time"
)

// newGroup starts the worker in its own process group, so a stop reaches its children.
func newGroup(c *exec.Cmd) { c.SysProcAttr = &syscall.SysProcAttr{Setpgid: true} }

// stopGroup sends TERM to a process group and KILL five seconds later if it is still alive.
func stopGroup(pid int) {
	syscall.Kill(-pid, syscall.SIGTERM)
	for i := 0; i < 50; i++ {
		if syscall.Kill(-pid, 0) != nil {
			return
		}
		time.Sleep(100 * time.Millisecond)
	}
	syscall.Kill(-pid, syscall.SIGKILL)
}

// stopChild sends TERM to a child polybrief process; it stops its own workers.
func stopChild(c *exec.Cmd) { c.Process.Signal(syscall.SIGTERM) }
