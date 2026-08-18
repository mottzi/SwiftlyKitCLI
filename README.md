# SwiftlyKitCLI

`swiftlykit` is a CLI that cross-compiles SwiftPM projects from macOS to
statically linked ARM64 or x86-64 Linux Musl executables. It manages the
required Swift toolchain and Static Linux SDK and verifies the resulting
static executable.

This CLI depends on the [SwiftlyKit](https://github.com/mottzi/SwiftlyKit) Swift library.

## Requirements

- Apple silicon Mac running macOS 13 or later
- Xcode or Command Line Tools with Swift 6.3 or later

## Installation

Clone the repository and run the installation script:

```sh
git clone https://github.com/mottzi/SwiftlyKitCLI.git
cd SwiftlyKitCLI
./install.sh
```

The installer builds the checked out source code, installs `swiftlykit` to
`~/.local/bin`, and adds that directory to `PATH` for zsh or Bash when needed.
Run `./install.sh --help` to see supported installation customization.

### Manual installation

Clone the repository and build the source code:

```sh
git clone https://github.com/mottzi/SwiftlyKitCLI.git
cd SwiftlyKitCLI
swift build -c release
```

Copy the executable to a directory in your home directory:

```sh
mkdir -p "$HOME/.local/bin"
cp .build/release/swiftlykit "$HOME/.local/bin/swiftlykit"
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
swiftlykit --version
```

## Quick start

Build the only executable product in the current package for x86-64 Linux:

```sh
swiftlykit build . \
  --architecture x86_64 \
  --install-environment \
  --resolve-dependencies
```

This command permits `swiftlykit` to install missing environment components.
If the build needs dependency resolution, it also permits `swiftlykit` to
resolve dependencies and retry the build.

Select a product and publish its executable and resource bundles to an output
directory:

```sh
swiftlykit build /path/to/MyPackage \
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
swiftlykit --help
swiftlykit build --help
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
| `6` | Verification, stripping, publication, or completion failure |
| `7` | Another process owns the required mutation |
| `130` | Cancellation |
