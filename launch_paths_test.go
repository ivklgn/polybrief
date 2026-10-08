package main

import (
	"path/filepath"
	"testing"
)

func TestSecretLike(t *testing.T) {
	yes := []string{".env", ".env.production", ".envrc", "a.pem", "sub/dir/b.PEM", "k.key", "x.p12", "y.pfx",
		"id_rsa", "id_rsa.pub", "ID_ED25519", "id_ecdsa", "id_dsa.old"}
	no := []string{"a.txt", "envelope.md", "environment.go", "keys.go", "pemberton.md"}
	for _, p := range yes {
		if !secretLike(p, nil) {
			t.Errorf("%s must look like a secret", p)
		}
	}
	for _, p := range no {
		if secretLike(p, nil) {
			t.Errorf("%s must not look like a secret", p)
		}
	}
	if !secretLike("config/prod.yaml", []string{"config/*"}) || !secretLike("Notes/Token.TXT", []string{"*.txt"}) {
		t.Error("caller patterns match the path or the name, ignoring case")
	}
	if secretLike("config/prod.yaml", []string{"["}) {
		t.Error("a bad pattern matches nothing")
	}
}

func TestInside(t *testing.T) {
	root := filepath.Join(string(filepath.Separator), "repo")
	for p, want := range map[string]bool{
		root:                               true,
		filepath.Join(root, "a", "b.md"):   true,
		filepath.Join(root+"2", "a.md"):    false,
		filepath.Join(root, "..", "x.md"):  false,
		string(filepath.Separator) + "tmp": false,
	} {
		if inside(p, root) != want {
			t.Errorf("inside(%s, %s) = %v, want %v", p, root, !want, want)
		}
	}
	if !inside(filepath.Join(string(filepath.Separator), "tmp"), string(filepath.Separator)) {
		t.Error("everything lies inside the root directory")
	}
}
