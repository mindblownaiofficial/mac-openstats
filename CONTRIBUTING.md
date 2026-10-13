# Contributing to OpenStats

Thanks for helping make a free system monitor better. Issues and pull requests
are welcome.

## Getting set up

```bash
git clone https://github.com/woodsjohn16/mac-openstats.git
cd mac-openstats
swift build
swift run OpenStats --dump    # prints one sample of every monitor
./Scripts/build-app.sh && open build/OpenStats.app
```

Only the Xcode Command Line Tools are required. If you use Xcode, open the folder
directly; it understands `Package.swift`.

## Guidelines

- Keep it dependency-free and built on public APIs. No private frameworks, no
  helper daemons, no root.
- Avoid `@State`, `@StateObject` and `@Observable`: the Command Line Tools
  toolchain cannot expand SwiftUI's macros. Use `@EnvironmentObject` and
  explicit `Binding`s (see `docs/ARCHITECTURE.md`).
- Each data source lives in its own `Monitors/*Monitor.swift` with a `sample()`
  method. Add new numbers to the matching struct in `Core/Models.swift`.
- Measure before and after: the app should stay well under 2% CPU at the default
  refresh rate. Check with `top -pid $(pgrep -x OpenStats)`.
- Match the existing style: 4-space indentation, no force unwraps outside
  scripts, short comments that explain *why*.

## Reporting bugs

Please include your macOS version, Mac model, and the output of:

```bash
swift run OpenStats --dump
```

## Releasing

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in
   `Resources/Info.plist` and add a section to `CHANGELOG.md`.
2. Commit, then tag and push:

   ```bash
   git tag v0.2.0 && git push origin main --tags
   ```

3. The `Release` GitHub Actions workflow builds the `.dmg` and `.pkg` and
   attaches them to a GitHub release for that tag.
