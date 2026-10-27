# CLAUDE.md — ra-port (Josh's fork)

Native SDL2 source port of Command & Conquer: Red Alert, built from EA's GPLv3 source release.
This is Josh's fork of `dk8827/ra-port`. **The goal is playing it on Josh's iPhone.** Android is
out of scope for now (Josh has no Android device, 2026-10-27). `README.md` is upstream's full
build guide. `docs/DECISIONS.md` logs every setup choice and fix, with who made it.

## Remotes and branches
- `origin` = `killercatfish/ra-port` (Josh's fork). `upstream` = `dk8827/ra-port`.
- Local `main` tracks `upstream/main` and stays a clean mirror. Update it with
  `git fetch upstream && git checkout main && git merge --ff-only upstream/main`.
- Work happens on branches. `josh/setup` holds the initial setup. Commit, don't push: Josh reviews and pushes.
- Never open PRs upstream unless Josh asks.

## Game data: never commit it
- The repo holds source only. Game data lives in the git-ignored `assets/` tree:
  - `assets/redalert/allies`, `assets/redalert/soviet`: the prepared disc roots the game and
    the mobile builds read.
  - `assets/freeware-download/`: the 2008 EA freeware disc zips, ISOs and extracted discs
    (source: `downloads.cnc-comm.com/red-alert/iso/RA_Allies.zip` and `RA_Soviet.zip`).
- Re-prepare with `scripts/prepare_assets_from_local.sh --allies assets/freeware-download/disc-Allies --soviet assets/freeware-download/disc-Soviet`.
- `docs/status/` (screenshots) is ignored too, because screenshots contain game art.
- **Before every commit**, run `git status` and confirm no `.MIX`, `.VQA`, `.AUD`, ISO, zip,
  screenshot, `.apk` or `.app` is staged. The iOS `.app` and any APK bundle the game data:
  never upload or share them.

## This Mac's toolchain quirks (2026-10-27)
- Use the native arm64 Homebrew: put `/opt/homebrew/bin` first on PATH. The `/usr/local`
  Homebrew is an Intel install under Rosetta, and its cmake makes clang target x86_64.
- Command Line Tools 26.6 has a stray `MacOSX27.0.sdk` that its linker can't read. Pin the SDK
  for desktop builds and tests:
  `export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk` and configure with
  `-DCMAKE_OSX_SYSROOT=$SDKROOT`.
- Xcode 27.1 is at `/Applications/Xcode.app`, but `xcode-select` still points at Command Line
  Tools. For iOS work, `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## macOS desktop
```sh
export PATH=/opt/homebrew/bin:$PATH SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
cmake -S . -B build -G Ninja -DCMAKE_OSX_SYSROOT=$SDKROOT
cmake --build build --target redalert_mac -j 8
tests/run_script_tests.sh
scripts/run_mac_dev.sh --no-build
```
`scripts/smoke_mac_menu.sh` only finds the game window when it opens on the current Space.
Otherwise it screenshots the whole desktop, so check the image before trusting it.

## iOS (the target platform)
```sh
export PATH=/opt/homebrew/bin:$PATH DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
scripts/build_ios_debug.sh                                   # simulator app
scripts/run_ios_simulator.sh --no-build --device "iPhone 17" # install + launch
xcrun simctl io booted screenshot docs/status/ios.png         # check it (saved sideways)
RA_IOS_DEVELOPMENT_TEAM=<TEAMID> scripts/build_ios_debug.sh --device   # signed device build
```
- Logs: `xcrun simctl spawn booted log show --last 2m --predicate 'process == "redalert_ios"' --style compact`.
- iOS-specific code lives in `PORT/IOS/src/` and `ios/` (CMake target, `Info.plist.in`).
- The iOS 27 SDK requires the UIScene life cycle and SDL2 has none. `ios_app_delegate.m` gives SDL's
  windows a scene by hooking `-[UIWindow makeKeyAndVisible]`. If windows stop appearing after an
  SDL bump, look there first.

## Linux and Android
Linux: see README; CI builds it (`.github/workflows/linux-build.yml`, also `macos-build.yml`).
Android: parked. The SDK, NDK 28.2.13676358 and CMake 3.22.1 are installed under
`/usr/local/share/android-commandlinetools`. Set `ANDROID_HOME` to that path and
`JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`, then run
`scripts/build_android_debug.sh`.

## How to change code (upstream's philosophy)
- Be conservative. Keep the original Westwood code in `CODE/` recognizable; don't reformat or modernize it.
- Prefer small, platform-specific support files (`PORT/MAC`, `PORT/IOS`, `PORT/ANDROID`) and
  shims over edits to game code. No broad rewrites.
- Keep each change small and explain why in its commit message, so it could go upstream later.
- Add a focused test in `tests/` when changing shims or file-format code, and keep
  `tests/run_script_tests.sh` passing with no game data present.
