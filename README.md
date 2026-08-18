# SwiftlyKitCLI

`swiftlykit` is the command-line interface for
[SwiftlyKit](https://github.com/mottzi/SwiftlyKit).

Give it the root of a trusted local Swift package. It prepares an official
Swift toolchain and matching Static Linux SDK, builds one executable product,
and verifies the result as a static Linux executable.

`swiftlykit` can:

- build for ARM64 or x86-64 Linux Musl on an Apple silicon Mac;
- install Swiftly, the selected toolchain, and its matching SDK when you permit
  the installation;
- publish the executable and its resource bundles as one runnable directory;
- show each stage of the SwiftlyKit workflow; and
- clean build storage or remove exact Swiftly-managed resources.

SwiftlyKit owns the build and environment operations. For details about that
workflow, see the [SwiftlyKit repository](https://github.com/mottzi/SwiftlyKit).

## Requirements

- Apple silicon Mac
- macOS 13 or later
- Swift 6.3 or later
- An active macOS SDK from Xcode or Command Line Tools
- An unsandboxed terminal
- A trusted local Swift package to build

Swiftly 1.0 or later is also required. `swiftlykit` can install Swiftly when
you use `--install-environment`. It does not install Xcode or select the active
developer directory.

## Installation

Clone the repository and build a release executable:

```sh
git clone git@github.com:mottzi/SwiftlyKitCLI.git
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

To make the change permanent in zsh, add the same line to `~/.zprofile`, and
then start a new terminal. Confirm the installation:

```sh
swiftlykit --version
```

## Quick start

Build the only executable product in the current package for ARM64 Linux:

```sh
swiftlykit build . \
  --architecture aarch64 \
  --install-environment \
  --resolve-dependencies
```

This command permits `swiftlykit` to install missing environment components.
If the build needs dependency resolution, it also permits `swiftlykit` to
resolve dependencies and retry the build.

Select a product and publish one runnable directory:

```sh
swiftlykit build /path/to/MyPackage \
  --product MyTool \
  --architecture x86_64 \
  --output-path /path/to/output/MyTool \
  --install-environment \
  --resolve-dependencies
```

The published directory contains the verified executable and its required
resource bundles. Keep the complete directory together. An existing output
directory is not replaced unless you add `--replace-output`.

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
