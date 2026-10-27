# ra-port setup status (2026-10-27)

Fork: https://github.com/killercatfish/ra-port · branch `josh/setup` (**not pushed**)
Decisions and reasons: `docs/DECISIONS.md`. How to work in the repo: `CLAUDE.md`.

## What works

| | Item | Notes |
|---|---|---|
| ✅ | Fork and clone | `origin` = killercatfish/ra-port, `upstream` = dk8827/ra-port, `main` tracks upstream |
| ✅ | macOS desktop build | Native arm64 `build/redalert_mac`, no code changes. Needs the SDK pin in `CLAUDE.md` (a machine quirk) |
| ✅ | Tests | `tests/run_script_tests.sh` passes ("run script tests passed") |
| ✅ | Game data | 2008 EA freeware Allied + Soviet discs, prepared under the git-ignored `assets/redalert/` |
| ✅ | macOS main menu | Reaches the main menu, v3.03 |
| ❌ | macOS skirmish | Not tested: needs mouse input I couldn't drive non-interactively |
| ✅ | iOS simulator app | Builds with Xcode 27.1 after 2 small fixes (below) |
| ✅ | iOS simulator run | Reaches the main menu on iPad Pro 13-inch (M5) and iPhone 17, iOS 27.0, with audio |
| ❌ | iOS skirmish | Not tested: needs touch input |
| ✅ | iOS device build | Signed with team MTXB24VFYK, installed on Josh's iPhone 17, and it runs (Josh confirmed 2026-10-27) |
| ⏸ | Android APK | Dropped at your request. Toolchain installed; build stopped partway, no APK |
| ✅ | Linux CI | Upstream already has `.github/workflows/linux-build.yml` (build + tests, no data) and `macos-build.yml`; nothing added |

## Changes to upstream code
1. `ios/CMakeLists.txt`: the default iOS deployment target goes from 13.0 to 15.0. Xcode 27
   rejects anything below 15.0, which broke every CMake compile check.
2. `ios/Info.plist.in` + `PORT/IOS/src/ios_app_delegate.m`: the app adopts the UIScene life cycle.
   iOS 27 refuses to launch apps built with its SDK unless they use scenes, and SDL2 has no scene
   support. A small scene delegate plus a hook on `-[UIWindow makeKeyAndVisible]` attaches SDL's
   windows to the app's scene. SDL is unchanged. Both fixes are worth offering upstream later.
3. `.gitignore`: added `docs/status/`, because screenshots contain game art.

4. `scripts/build_ios_debug.sh`: device builds pass `-allowProvisioningUpdates`, so Xcode can create the first signing profile.
5. `ios/CMakeLists.txt` + `ios/Info.plist.in`: the bundle ID is the `RA95_IOS_BUNDLE_ID` build option (default unchanged); upstream's ID is registered to another team.

No desktop or game code (`CODE/`, `PORT/MAC`) was changed.

## What Josh needs to do

**1. Review and push the branch** (global rule: Claude commits, Josh pushes):
```sh
cd ~/dev/ra-port
git log --oneline main..josh/setup
git push -u origin josh/setup
```

**2. Build for your iPhone** (needs your Apple ID; a free account works for 7-day installs):
- Xcode → Settings → Accounts → add your Apple ID. Note the Team ID shown for "Personal Team",
  or run `defaults read com.apple.dt.Xcode IDEProvisioningTeams` after signing in.
- On the iPhone: Settings → Privacy & Security → Developer Mode → on (needs a restart). Then
  connect it by USB and tap "Trust".
```sh
cd ~/dev/ra-port
export PATH=/opt/homebrew/bin:$PATH DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
RA_IOS_DEVELOPMENT_TEAM=YOURTEAMID scripts/build_ios_debug.sh --device
xcrun devicectl list devices
xcrun devicectl device install app --device <DEVICE-ID> ios/build-device/Debug-iphoneos/redalert_ios.app
```
- If signing fails because `com.raport.redalert` is "not available", someone else has
  registered that ID. Change it in **both** `ios/CMakeLists.txt` (`XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER`)
  and `ios/Info.plist.in` (`CFBundleIdentifier`) to e.g. `com.killercatfish.redalert`, then rebuild.
- The first launch copies about 1.1 GB of game data into the app's storage, so give it a moment.
  With a free account, the install expires after 7 days; rebuild and reinstall to renew it.
- The app bundles the game data. Don't share or upload it.

**3. Optional:** confirm the `ra-port` entry in `~/dev/roadmap/projects.yaml` (committed as
`ff23d90`). I filed it as `kind: personal`, `bucket: lab`; change the bucket if it fits better
elsewhere. It has no Eagle board card yet.

## Machine changes outside the repo
- Native Homebrew (`/opt/homebrew`): installed ninja, pkg-config, sdl2, cmake, mas, gradle, and
  upgraded openjdk@17.
- Android SDK at `/usr/local/share/android-commandlinetools`: added platform 36,
  build-tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1, platform-tools.
- Xcode: iOS 27 simulator runtime downloaded (`xcodebuild -downloadPlatform iOS`).
- Left alone: the stray `/Library/Developer/CommandLineTools/SDKs/MacOSX27.0.sdk`. Deleting it
  (with `sudo`) would remove the need for the SDK pin, but that's your call.
- The iOS Simulator (iPhone 17 and iPad Pro) is still running with the game open.

## Paths
- Screenshots (git-ignored): `docs/status/mac-menu.png`, `docs/status/ios-sim-menu.png` (iPad),
  `docs/status/ios-sim-iphone-menu.png` (iPhone). The iOS ones are saved sideways.
- macOS binary: `build/redalert_mac`
- iOS simulator app: `ios/build-simulator/Debug-iphonesimulator/redalert_ios.app`
- Game data: `assets/redalert/{allies,soviet}`; source zips, ISOs and extracted discs in `assets/freeware-download/`

## Update: on the iPhone (2026-10-27)
Done: built, paired, installed and trusted, and the game runs on the phone. To rebuild and reinstall
(e.g. when the 7-day free-account install expires), see "Josh's iPhone" in `CLAUDE.md`.
Possible next feature: pinch to magnify part of the 640x400 frame. It would live in the port's
display and touch code, not the game code. Not started.
