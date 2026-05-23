# 🎧 AirPodsBar

A lightweight native macOS menu bar app that shows your AirPods battery in real time — Pro, regular, Max, and Beats supported.

![preview](Assets/preview.png)

## Features

- **Live battery** for the **left bud**, **right bud**, and the **charging case**
- **In-case detection** — clearly shows which bud is docked in the case
- **Charging indicator** — animated breathing battery bar while charging
- **Multi-device support** — auto-detects AirPods, AirPods Pro, AirPods Max, and Beats
- **Global hotkey** — `⌥⌘A` toggles the popover from anywhere, no need to reach for the menu bar
- **Low battery alert** — menu bar icon turns orange when a bud drops below 20%
- **Native notifications** when battery is low or starts charging
- **Connect / Disconnect** AirPods directly from the app (no Bluetooth menu needed)
- **Light / Dark theme** that follows your preference
- **Launch at login** toggle
- Auto-refreshes every **30 seconds**

---

## What's new in v2.0

- 🌍 Full English interface (previously Romanian-only)
- ⌥⌘A global hotkey to toggle the popover from anywhere
- Multi-device support — AirPods 2/3, AirPods Pro, AirPods Max, Beats
- Charging breathing animation on the battery bar
- Orange menu bar icon when any bud drops below 20%
- Smarter `resolveAddress()` for non-AirPods devices (Beats fix)
- Various small bug fixes around battery edge cases (0%)

---

## Install

### Option A — Pre-built binary (recommended)

1. Download `AirPodsBar.app.zip` from the [Releases page](https://github.com/VIK-DD/AirPodsBar/releases/latest)
2. Unzip and drag `AirPodsBar.app` into `/Applications`
3. Right-click → **Open** (first time only, to bypass Gatekeeper)
4. Approve the Bluetooth permission prompt when it appears

### Option B — Build from source

```bash
git clone https://github.com/VIK-DD/AirPodsBar.git
cd AirPodsBar
open AirPodsBar.xcodeproj
```

In Xcode: **Product → Run** (`⌘R`). For a Release build:

```bash
xcodebuild -project AirPodsBar.xcodeproj -scheme AirPodsBar -configuration Release build
cp -R build/Release/AirPodsBar.app /Applications/
```

### Option C — One-line install script

```bash
bash install.sh
```

Compiles directly with `swiftc`, installs to `/Applications`, and sets up launch-at-login.

---

## Launch at login

Use the toggle inside the app — or do it manually:

```bash
cp com.vik.airpodsbar.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.vik.airpodsbar.plist
```

To disable:

```bash
launchctl unload ~/Library/LaunchAgents/com.vik.airpodsbar.plist
```

---

## Keyboard shortcut

| Shortcut | Action |
|---|---|
| `⌥⌘A` | Toggle popover from anywhere |

No Accessibility permission required — uses Carbon's `RegisterEventHotKey`.

---

## Troubleshooting

**Batteries show as `--`**
- Make sure the AirPods are connected to the Mac
- Press the Refresh button (↻) inside the popover
- macOS only broadcasts battery data while the buds are in active use

**Connect / Disconnect doesn't work**
- The app uses `IOBluetooth` natively — no `blueutil` needed
- Make sure the device is paired in System Settings → Bluetooth

**Doesn't launch at login**
- Make sure the app lives at `/Applications/AirPodsBar.app`
- Reload the agent: `launchctl load ~/Library/LaunchAgents/com.vik.airpodsbar.plist`

**Hotkey `⌥⌘A` doesn't fire**
- Another app may have already registered this combination (rare). Quit competing apps and relaunch AirPodsBar.

---

## Project structure

```
AirPodsBar/
├── AirPodsBar.xcodeproj/
│   └── project.pbxproj
├── AirPodsBar/
│   ├── main.swift             # Entry point
│   ├── AppDelegate.swift      # Menu bar + popover + global hotkey
│   ├── BatteryMonitor.swift   # system_profiler + IOBluetooth integration
│   ├── ContentView.swift      # SwiftUI UI
│   └── AirPodsBar.entitlements
├── com.vik.airpodsbar.plist   # LaunchAgent for launch-at-login
└── install.sh                 # One-line build & install script
```

---

## Requirements

- macOS 12.0 (Monterey) or later
- AirPods, AirPods Pro, AirPods Max, or Beats (any model that reports battery via `system_profiler`)

---

## License

MIT — see [LICENSE](LICENSE).

Built with ❤️ for macOS.
