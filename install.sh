#!/bin/sh
# Install polybrief on macOS or Linux:
#   curl -fsSL https://raw.githubusercontent.com/ivklgn/polybrief/main/install.sh | sh
# POLYBRIEF_VERSION=vX.Y.Z picks a release (default: latest).
# POLYBRIEF_INSTALL_DIR picks the target directory (default: ~/.local/bin).
set -eu

# The whole script is one function, so a download cut in the middle runs nothing.
main() {
	repo=ivklgn/polybrief
	dir=${POLYBRIEF_INSTALL_DIR:-$HOME/.local/bin}
	version=${POLYBRIEF_VERSION:-latest}

	case $(uname -s) in
	Darwin) os=darwin ;;
	Linux) os=linux ;;
	*) fail "unsupported OS $(uname -s); on Windows use install.ps1" ;;
	esac
	case $(uname -m) in
	x86_64 | amd64) arch=amd64 ;;
	arm64 | aarch64) arch=arm64 ;;
	*) fail "unsupported CPU $(uname -m)" ;;
	esac

	if [ "$version" = latest ]; then
		base=https://github.com/$repo/releases/latest/download
	else
		base=https://github.com/$repo/releases/download/$version
	fi
	file=polybrief_${os}_${arch}.tar.gz

	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	echo "Downloading $base/$file"
	curl -fsSL -o "$tmp/$file" "$base/$file" || fail "download failed; is there a release at https://github.com/$repo/releases?"
	curl -fsSL -o "$tmp/checksums.txt" "$base/checksums.txt" || fail "cannot download checksums.txt"

	want=$(awk -v f="$file" '$2 == f { print $1 }' "$tmp/checksums.txt")
	if command -v sha256sum >/dev/null 2>&1; then
		got=$(sha256sum "$tmp/$file" | cut -d' ' -f1)
	else
		got=$(shasum -a 256 "$tmp/$file" | cut -d' ' -f1)
	fi
	[ -n "$want" ] && [ "$want" = "$got" ] || fail "checksum mismatch for $file"

	tar -xzf "$tmp/$file" -C "$tmp" polybrief
	mkdir -p "$dir"
	chmod +x "$tmp/polybrief"
	mv "$tmp/polybrief" "$dir/polybrief"
	echo "Installed $("$dir/polybrief" --version) to $dir/polybrief"

	case ":$PATH:" in
	*":$dir:"*) ;;
	*) echo "Add $dir to PATH, for example: echo 'export PATH=\"$dir:\$PATH\"' >> ~/.profile" ;;
	esac
}

fail() {
	echo "polybrief install: $1" >&2
	exit 1
}

main "$@"
