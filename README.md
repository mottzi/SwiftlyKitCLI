# TripleCLI

Build static Linux executables from Swift packages on your Mac.

The `triple` command selects a Swift toolchain and Static Linux SDK, builds your
package, and verifies the executable. It supports ARM64 and x86-64 Linux with
Musl. It uses the [Triple](https://github.com/mottzi/Triple) library.

## Install

You need an Apple silicon Mac with macOS 13 or later, and Xcode or Command Line
Tools with Swift 6.3 or later.

```sh
git clone https://github.com/mottzi/TripleCLI.git
cd TripleCLI
./install.sh
```

The installer builds the source and installs `triple` in `~/.local/bin`. It adds
that directory to your zsh or Bash startup file when needed. Open a new terminal,
then check the installation:

```sh
triple --version
```

If your shell cannot find `triple`, add the directory for the current session:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Use `./install.sh --help` for a custom installation directory or to keep your
shell startup file unchanged.

## Build your package

Your package must have an executable product and support Linux Musl. Open the
package directory that contains `Package.swift`, then run:

```sh
triple build . --install-environment --resolve-dependencies
```

This builds the package's only executable for x86-64 Linux in release mode.
The result lists the executable path and its resource bundles.

`--install-environment` allows Triple to install missing Swiftly, Swift
toolchain, and Static Linux SDK components. `--resolve-dependencies` allows
SwiftPM to resolve package dependencies when needed. Omit these flags if you
want the command to stop when either step is required.

Dependency resolution can download packages and update `Package.resolved`.
SwiftPM runs package manifests and build plugins. Build only packages you trust.

You can pass a package path instead of `.`. If you omit the path, Triple uses
the current directory.

## Choose what to build

If the package has more than one executable, select one with `--product`.
Use `aarch64` for ARM64 Linux or `x86_64` for x86-64 Linux:

```sh
triple build /path/to/MyPackage \
  --product MyServer \
  --architecture aarch64 \
  --install-environment \
  --resolve-dependencies
```

Add `--configuration debug` for a debug build. Add `--swift-version 6.3.3` to
use that exact Swift release. It must support the package and target.

Without `--swift-version`, Triple uses the exact version in the nearest
`.swift-version` file. That version must be an official stable release that
supports the package and target. If there is no such file, Triple prefers the
newest installed compatible Swift toolchain and SDK. Otherwise, it selects the
newest compatible official release.

To list executable products or compatible environments:

```sh
triple products . --install-environment
triple environments .
```

## Export the result

Create the parent directory, then choose a new output directory:

```sh
mkdir -p ./dist
triple build . \
  --product MyServer \
  --output-path ./dist/MyServer \
  --strip \
  --install-environment \
  --resolve-dependencies
```

The output directory contains the verified executable and its required
resource bundles. Copy the whole directory to Linux and keep its contents
together. Run the executable on a Linux machine with the selected architecture.

`--strip` removes symbols from the executable. An existing output directory
is left unchanged unless you add `--replace-output`. That flag replaces the
directory and its contents.

## Output and cancellation

Results go to standard output. Progress and errors go to standard error.
Add `--verbose` for commands and live tool output, or `--json` for one JSON
result. You cannot use both flags together.

Press Control-C to cancel. Press it again to force exit. Cancellation returns
exit status `130`; other failures return a nonzero status.

| Status | Meaning |
| --- | --- |
| `0` | Success, help, version, or a completed readiness check |
| `1` | Unexpected failure |
| `2` | Invalid command or option |
| `3` | Missing environment components need installation permission |
| `4` | Environment, dependency, cleanup, or removal failure |
| `5` | Build or source-stability failure |
| `6` | Verification, stripping, export, or cleanup after export failure |
| `7` | Another process owns the required operation |
| `130` | Cancellation |

## Help and commands

```sh
triple --help
triple build --help
```

| Command | Use it to |
| --- | --- |
| `host-readiness` | Check your Mac and developer tools. |
| `install-command-line-tools` | Open Apple's Command Line Tools installer. |
| `environments` | List compatible Swift environments without installing them. |
| `assess` | Check the selected environment without changing it. |
| `prepare` | Prepare the selected environment. Add `--install-environment` if needed. |
| `products` | List executable products in a prepared environment. |
| `resolve` | Resolve package dependencies. |
| `build` | Build and verify an executable. |
| `clean` | Remove compiled products and intermediate files. |
| `reset` | Remove the selected SwiftPM scratch directory. |
| `remove` | Remove an exact Swift toolchain, SDK, or environment. |

If you used `swiftlykit`, change scripts and aliases to use `triple`.
Regenerate shell completions with `triple --generate-completion-script zsh`
or the name of your shell.

## Uninstall

Installed toolchains and SDKs stay in place when you uninstall the CLI. To
remove any of those first, read `triple remove --help`.

Remove the executable from its installation directory. For the default path:

```sh
rm "$HOME/.local/bin/triple"
```

## Support and related tools

[Report an issue](https://github.com/mottzi/TripleCLI/issues) with your macOS
version, `triple --version`, the command, and its error output.

For a native interface, see [Triple for macOS](https://github.com/mottzi/TripleApp).
Visit the [Triple website](https://triple.mottzi.codes) for the library, CLI, and
app. To change or test the CLI, see [Contributing](CONTRIBUTING.md).
