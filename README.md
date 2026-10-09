# TripleCLI

`triple` is a CLI that cross-compiles SwiftPM projects from macOS to
statically linked ARM64 or x86-64 Linux Musl executables. It manages the
required Swift toolchain and Static Linux SDK and verifies the resulting
static executable.

This CLI depends on the [Triple](https://github.com/mottzi/Triple) Swift library.

## Requirements

- Apple silicon Mac running macOS 13 or later
- Xcode or Command Line Tools with Swift 6.3 or later

## Installation

TripleCLI source version `0.2.1` is available on `main`. The package pins the
matching Triple library revision from its public repository. A sibling library
checkout is not required.

The existing [`0.2.1` release tag](https://github.com/mottzi/TripleCLI/releases/tag/0.2.1)
predates the rebrand and uses the SwiftlyKitCLI module and `swiftlykit`
executable names. Clone the current `main` branch below to install `triple`.

Clone the repository and run the installation script:

```sh
git clone https://github.com/mottzi/TripleCLI.git
cd TripleCLI
./install.sh
```

The installer builds the checked out source code, installs `triple` to
`~/.local/bin`, and adds that directory to `PATH` for zsh or Bash when needed.
Run `./install.sh --help` to see supported installation customization.

### Manual installation

Clone the repository and build the source code:

```sh
git clone https://github.com/mottzi/TripleCLI.git
cd TripleCLI
swift build -c release
```

Copy the executable to a directory in your home directory:

```sh
mkdir -p "$HOME/.local/bin"
cp .build/release/triple "$HOME/.local/bin/triple"
```

Add that directory to `PATH` for the current shell:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Make the change permanent for zsh:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
```

Or for Bash:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bash_profile"
```

Then start a new terminal and confirm the installation:

```sh
triple --version
```

## Quick start

Build the only executable product in the current package for x86-64 Linux:

```sh
triple build . \
  --architecture x86_64 \
  --install-environment \
  --resolve-dependencies
```

This command permits `triple` to install missing environment components.
If the build needs dependency resolution, it also permits `triple` to
resolve dependencies and retry the build.

Select a product and export its executable and resource bundles to an output
directory:

```sh
triple build /path/to/MyPackage \
  --product MyTool \
  --architecture x86_64 \
  --output-path /path/to/output/MyTool \
  --install-environment \
  --resolve-dependencies
```

The output directory contains the verified executable and any required resource
bundles. Keep its contents together. An existing output directory is not
replaced unless you add `--replace-output`.

## Commands

| Command | Operation |
| --- | --- |
| `host-readiness` | Check the Mac and its developer tools. |
| `install-command-line-tools` | Request Apple's interactive Command Line Tools installer. |
| `environments` | List compatible Swift environments without installing them. |
| `assess` | Assess one exact Swift environment without changing it. |
| `prepare` | Prepare one selected Swift environment. |
| `products` | List executable products in the package. |
| `resolve` | Resolve package dependencies. |
| `build` | Build and verify one executable product. |
| `clean` | Remove compiled products and intermediate files. |
| `reset` | Remove the selected SwiftPM scratch directory. |
| `remove` | Remove an exact toolchain, SDK, or complete environment. |

Run help for the complete syntax:

```sh
triple --help
triple build --help
```

## Migration and local development

The executable is now `triple`. Replace `swiftlykit` invocations in scripts,
terminal aliases, and shell completion setup. Regenerate completions with
`triple --generate-completion-script` after building the new executable.
The Swift module and runtime are now `TripleCLI` and `TripleCLIRuntime`.
The library module, facade, error, and event types are `Triple`, `TripleError`,
and `TripleEvent`. Swiftly remains the external tool used to manage Swift
installations, so its names and storage options retain that spelling.

Existing local checkout folders can keep their old names. Normal builds resolve
the pinned Triple revision from GitHub. For optional local development against
a sibling checkout still named `SwiftlyKit`, configure a local SwiftPM mirror:

```sh
mkdir -p .swiftpm
ln -s ../../SwiftlyKit .swiftpm/Triple
swift package config set-mirror \
  --original https://github.com/mottzi/Triple.git \
  --mirror "file://$(pwd)/.swiftpm/Triple"
swift test
swift build -c release --product triple
```

The ignored symlink gives the mirror the canonical package identity `triple`,
so local builds preserve the committed lockfile. The sibling library must contain
the pinned rebrand commit. Remove the mirror to return to the public dependency:

```sh
swift package config unset-mirror --original https://github.com/mottzi/Triple.git
rm .swiftpm/Triple
```

For development against a sibling checkout named `Triple`, use an editable dependency:

```sh
swift package edit Triple --path ../Triple
swift test
swift package unedit Triple
```

A package path defaults to the current directory. It must identify the exact
package root that contains `Package.swift`.

Read-only commands do not install components. Commands that can install
components require `--install-environment`. A build does not resolve package
dependencies unless you add `--resolve-dependencies`.

## Output and exit status

Normal results use standard output. Progress, warnings, and errors use standard
error. Add `--verbose` to show redacted commands and live process output.

Add `--json` to write one JSON result for automation. Do not use `--json` and
`--verbose` together.

| Status | Meaning |
| --- | --- |
| `0` | Success, help, version, or a completed readiness check |
| `2` | Invalid command or option |
| `3` | Environment preparation requires permission |
| `4` | Environment, dependency, cleanup, or removal failure |
| `5` | Build or source-stability failure |
| `6` | Verification, stripping, export, or completion failure |
| `7` | Another process owns the required mutation |
| `130` | Cancellation |
