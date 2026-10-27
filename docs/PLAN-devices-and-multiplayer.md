# Plan: Red Alert on the family's devices, then iPhone/iPad multiplayer

*Written 2026-10-27 by Claude at Josh's request. Status: step 1 done on Josh's iPhone (2026-10-27); iPad and son's phone next; the rest not started.*

## Goal
Red Alert on Josh's iPhone, his son's iPhone and the family iPad, without re-signing in Xcode
every week. Later, LAN skirmishes between them.

## 1. Sideloading with SideStore (in progress)
- A free Apple ID still signs apps for 7 days. SideStore can't change that, but it re-signs over
  Wi-Fi from the device itself, so the Mac is only needed once per device, for setup.
- Official route (docs.sidestore.io): the **iloader** desktop app (installed with
  `brew install --cask iloader`) plus the **LocalDevVPN** app from the App Store. We are not using
  the third-party all-on-phone "SideInstaller", which asks for the Apple ID password in an
  unofficial app.
- The app comes from `scripts/package_ios_ipa.sh` (`ios/build-device/RedAlert.ipa`, about 850 MB).
  It bundles game data, so it stays on family devices and is git-ignored.
- Each device: set it up once over USB with iloader, then AirDrop the .ipa and install it in SideStore.
- Apple ID: the free-account limit is 3 sideloaded apps per device, SideStore included. One
  account (Josh's) can serve all three devices.
- Switching from the Xcode install to the SideStore install gives the app a new bundle ID, so it
  installs as a separate app. Saves don't carry over. Delete the Xcode copy afterwards so it
  doesn't count toward the 3-app limit.

## 2. iPad first (single player)
The app is already universal (iPhone + iPad) and was tested in the iPad simulator. Installing it on
the real iPad is step 1 repeated. Getting single player solid on the iPad first is the right
order: it's the bigger screen, and it becomes the first device for network testing.

## 3. Multiplayer: what stands in the way
- **No multiplayer in the port yet.** Upstream draft PR #10 (dk8827/ra-port, +8.2k lines) restores
  the 1996 network lobby with a UDP transport (`PORT/MAC/src/lan_udp.cpp`, port 34835), for
  macOS and Linux only. It finds games by **UDP broadcast**.
- **iOS restricts broadcast.** Sending (and in practice receiving) broadcast/multicast needs
  Apple's `com.apple.developer.networking.multicast` entitlement, which must be requested from Apple
  and needs a paid developer account. Even with it, recent forum reports show `EACCES` on
  broadcast. Plain unicast UDP to a known address only needs the Local Network permission prompt.
- **The plan: Bonjour discovery plus unicast.**
  - Each copy of the game advertises itself with Bonjour (the `dns_sd` C API on iOS and macOS).
    Apple's guidance is that Bonjour doesn't need the multicast entitlement.
  - The transport keeps a list of the peers it found. Wherever the game "broadcasts", it sends one
    unicast packet to each peer instead.
  - All of this lives in the port's transport file; the game's lobby and lockstep code
    (`CODE/`) is untouched. Use it on macOS too, so a Mac and an iPad find each other. Linux keeps
    broadcast.
  - Info.plist needs `NSLocalNetworkUsageDescription` and `NSBonjourServices`.

## 4. Milestones
1. SideStore on Josh's iPhone, then the iPad and his son's phone.
2. Single player on the iPad.
3. Carry PR #10 on a fork branch; build it for the Mac.
4. Bonjour + unicast transport; first network test **Mac ↔ iPad**. Only one iOS device needs
   debugging, and the Mac gives full logs.
5. **iPad ↔ iPhone**, then 3 players. To the game, iPhone vs iPad doesn't matter; two iOS
   devices is just the harder setup to debug.

## 5. Risks to check early
- PR #10 is an unmerged draft; we'd be carrying it and may have to rebase when it changes.
- Lockstep networking needs the **same build on every device**. Rebuild and reinstall all of
  them together.
- iOS suspends apps when the screen locks or the app goes to the background, which would drop
  a network game. Check that the screen stays awake in-game.
- The lobby has text fields (player name, chat). Text entry on iOS is untested.
- Everyone has to be on the same Wi-Fi, and the Mac firewall must allow the game.
- Size: milestone 4 is several sessions of work, not a tweak.
