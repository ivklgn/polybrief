package main

import (
	"strings"
	"testing"
)

func TestVersionString(t *testing.T) {
	defer func(v string) { version = v }(version)
	version = "1.2.3"
	if got := versionString(); got != "1.2.3" {
		t.Fatalf("injected version: got %q", got)
	}
	version = ""
	if got := versionString(); got == "" || strings.HasPrefix(got, "v") {
		t.Fatalf("fallback version: got %q, want dev or a module version without v", got)
	}
}
