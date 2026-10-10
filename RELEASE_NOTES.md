# TripleCLI 0.3.0

TripleCLI 0.3.0 is the first release under the Triple name. The executable is
`triple`, the Swift module is `TripleCLI`, and the runtime is
`TripleCLIRuntime`. Replace `swiftlykit` in scripts and aliases, and regenerate
shell completions with `triple --generate-completion-script`.

This release pins Triple library commit
`a4fe262f215ff3236a238ba6ac335daf9f792a1e`. Builds use SwiftPM's default build
system, and resource bundle verification supports Swift Build output. The
dependency needs neither a sibling checkout nor an unpublished release tag.
Swiftly remains the tool used to manage Swift installations.

Cold dependency inspection now recognizes a host compiler failure even when
long fetch output removes its marker from the displayed diagnostic. SDK
recovery can retry another installed macOS SDK while keeping the selected Swift
version.

Install from source on an Apple silicon Mac with macOS 13 or later and Swift
6.3 or later:

```sh
git clone https://github.com/mottzi/TripleCLI.git
cd TripleCLI
git checkout 0.3.0
./install.sh
triple --version
```

The installer builds the checkout and installs `triple` to `~/.local/bin`.
This source release does not include compiled download assets.

The earlier `0.2.1` tag retains the SwiftlyKitCLI and `swiftlykit` names.

Validation on Apple silicon with Swift 6.4 passed all 15 CLI tests in release
configuration. A clean source copy resolved the prepared dependency through a
process-local Git mirror, built and installed into a temporary prefix, and
passed version, root help, build help, zsh completion generation, and
invalid-command exit status checks. Publish the pinned Triple commit before
publishing this CLI release.
