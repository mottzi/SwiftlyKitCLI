#!/bin/sh

set -eu

program_name=${0##*/}
install_directory=
update_path=1
temporary_executable=

usage() {
    cat <<EOF
Usage: $program_name [options]

Build and install swiftlykit from this repository checkout.

Options:
  --install-dir DIR  Install into DIR instead of \$HOME/.local/bin.
  --no-path-update   Do not update the zsh or Bash startup file.
  -h, --help         Show this help message.
EOF
}

fail() {
    printf '%s: %s\n' "$program_name" "$1" >&2
    exit 1
}

usage_error() {
    printf '%s: %s\n\n' "$program_name" "$1" >&2
    usage >&2
    exit 2
}

shell_quote() {
    escaped_value=$(printf '%s' "$1" | sed "s/'/'\\\\''/g")
    printf "'%s'" "$escaped_value"
}

cleanup() {
    if [ -n "$temporary_executable" ] && [ -e "$temporary_executable" ]; then
        rm -f "$temporary_executable"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --install-dir)
            [ "$#" -ge 2 ] || usage_error "--install-dir requires a path."
            install_directory=$2
            [ -n "$install_directory" ] || usage_error "--install-dir requires a path."
            shift 2
            ;;
        --no-path-update)
            update_path=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage_error "unknown option: $1"
            ;;
    esac
done

[ -n "${HOME:-}" ] || fail "HOME is not set."
[ "$(uname -s)" = "Darwin" ] || fail "swiftlykit requires macOS."
[ "$(uname -m)" = "arm64" ] || fail "swiftlykit requires an Apple silicon Mac."
command -v swift >/dev/null 2>&1 || fail "Swift 6.3 or later is required."

script_directory=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
[ -f "$script_directory/Package.swift" ] || fail "Package.swift was not found next to this script."

if [ -z "$install_directory" ]; then
    install_directory=$HOME/.local/bin
fi

printf 'Building swiftlykit from %s\n' "$script_directory"
(
    cd "$script_directory"
    swift build -c release --product swiftlykit
)

binary_directory=$(
    cd "$script_directory"
    swift build -c release --show-bin-path
)
source_executable=$binary_directory/swiftlykit
[ -x "$source_executable" ] || fail "the release build did not produce swiftlykit."

mkdir -p "$install_directory"
install_directory=$(CDPATH= cd "$install_directory" && pwd -P)
installed_executable=$install_directory/swiftlykit
[ ! -d "$installed_executable" ] || fail "$installed_executable is a directory."

temporary_executable=$(mktemp "$install_directory/.swiftlykit.install.XXXXXX")
trap cleanup 0 1 2 15

install -m 755 "$source_executable" "$temporary_executable"
if ! installed_version=$("$temporary_executable" --version); then
    fail "the installed executable failed verification."
fi

mv -f "$temporary_executable" "$installed_executable"
temporary_executable=

printf 'Installed %s\n%s\n' "$installed_executable" "$installed_version"

quoted_install_directory=$(shell_quote "$install_directory")
path_line="export PATH=$quoted_install_directory:\"\$PATH\""

case ":${PATH:-}:" in
    *":$install_directory:"*)
        printf '%s is already on PATH.\n' "$install_directory"
        exit 0
        ;;
esac

if [ "$update_path" -eq 0 ]; then
    printf 'Add the installation directory to PATH for the current shell:\n  %s\n' "$path_line"
    exit 0
fi

login_shell=${SHELL:-}
case "${login_shell##*/}" in
    zsh) startup_file=$HOME/.zshrc ;;
    bash) startup_file=$HOME/.bash_profile ;;
    *)
        printf '%s: warning: unsupported shell: %s\n' "$program_name" "${SHELL:-unknown}" >&2
        printf 'Add the installation directory to PATH:\n  %s\n' "$path_line"
        exit 0
        ;;
esac

if grep -Fqx "$path_line" "$startup_file" 2>/dev/null; then
    printf '%s is already configured in %s.\n' "$install_directory" "$startup_file"
    exit 0
fi

if [ -e "$startup_file" ] && [ ! -w "$startup_file" ]; then
    printf '%s: warning: %s is not writable.\n' "$program_name" "$startup_file" >&2
    printf 'Add the installation directory to PATH:\n  %s\n' "$path_line"
    exit 0
fi

if ! printf '\n%s\n' "$path_line" >> "$startup_file"; then
    printf '%s: warning: could not update %s.\n' "$program_name" "$startup_file" >&2
    printf 'Add the installation directory to PATH:\n  %s\n' "$path_line"
    exit 0
fi

printf 'Added %s to PATH in %s.\n' "$install_directory" "$startup_file"
printf 'Open a new terminal to run swiftlykit.\n'
