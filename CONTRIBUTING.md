# Contributing to TripleCLI

TripleCLI has three SwiftPM targets: the `TripleCLI` module, the
`TripleCLIExecutable` entry point, and `TripleCLITests`. The executable product
is `triple`. The runtime is `TripleCLIRuntime`.

## Build and test

Use an Apple silicon Mac with Swift 6.3 or later.

```sh
swift build --product triple
swift test
swift test -c release
```

For a release installation rehearsal, use a temporary directory and disable
shell startup changes:

```sh
triple_install_prefix=$(mktemp -d)
./install.sh --install-dir "$triple_install_prefix" --no-path-update
"$triple_install_prefix/triple" --version
"$triple_install_prefix/triple" --help
```

## Work on the library

The manifest normally resolves Triple from GitHub. To use a sibling Triple
checkout while you work on both repositories:

```sh
swift package edit Triple --path ../Triple
swift test
swift package unedit Triple
```

Keep editable dependencies out of release validation. Both `Package.swift` and
`Package.resolved` must select the intended remote dependency.

## Release preparation

TripleCLI 0.3.0 pins the published Triple commit
`a4fe262f215ff3236a238ba6ac335daf9f792a1e`. Before a future CLI release, check
that its exact library dependency is public.

Resolve and install from a fresh checkout using the public dependency.

Run release tests, then rehearse installation from a clean source copy. Check
version, help, shell completions, and invalid-command exit status. Keep command
logs and the exact source commit with the release evidence. Publish only after
the owner approves the release report.

The historical 0.2.1 tag uses the `SwiftlyKitCLI` module and `swiftlykit`
executable. Preserve that tag. The new CLI, module, and runtime names are
`triple`, `TripleCLI`, and `TripleCLIRuntime`. Swiftly keeps its own name because
it is the external tool that manages Swift installations.

Use [RELEASE_NOTES.md](RELEASE_NOTES.md) for the source-release notes.

