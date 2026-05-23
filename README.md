# 🎧 AirPodsBar

Native macOS menu bar app that shows your AirPods battery in real time — Pro, regular, Max, and Beats all supported.

## What it does
- Shows battery for the **left bud**, **right bud**, and the **case**
- Indicates if a bud is **in the case** (in-case detection)
- Indicates when a component is **charging** (animated breathing battery bar)
- **Connect / Disconnect** AirPods from inside the app
- Starts automatically at **login**
- **Multi-device support** — auto-detects AirPods, AirPods Pro, AirPods Max, and Beats
- **Global hotkey** `⌥⌘A` — toggle the popover from anywhere
- **Low-battery indicator** — menu bar icon turns orange when a bud drops below 20%
- Refreshes every **30 seconds**

---

## Install

### Step 1 — Download the pre-built app (recommended)
Grab the latest `.dmg` or `.zip` from the [Releases page](https://github.com/VIK-DD/AirPodsBar/releases/latest), then skip to Step 4.

### Step 2 — Open the project in Xcode (build from source)
```bash
open AirPodsBar.xcodeproj
```

### Step 3 — Build & Run
1. In Xcode: **Product → Run** (⌘R)
2. The first time, macOS will ask for Bluetooth permission — approve it

### Step 4 — Move to Applications (needed for launch-at-login)
```bash
# Release build
# Product → Archive → Distribute App → Copy App

# Or build directly from terminal:
xcodebuild -project AirPodsBar.xcodeproj -scheme AirPodsBar -configuration Release build

# Copy the .app into /Applications
cp -R build/Release/AirPodsBar.app /Applications/
```

### Step 5 — Enable launch-at-login
```bash
cp com.vik.airpodsbar.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.vik.airpodsbar.plist
```

To disable launch-at-login:
```bash
launchctl unload ~/Library/LaunchAgents/com.vik.airpodsbar.plist
```

---

## Troubleshooting

**Batteries show as "--"**
- Make sure the AirPods are connected to the Mac
- Try pressing the Refresh button (↻)
- macOS only broadcasts battery data while the buds are actively in use

**Connect/Disconnect doesn't work**
- The app uses `IOBluetooth` natively — no `blueutil` needed
- Make sure the device is paired in System Settings → Bluetooth
- Beats devices are also supported (added in v2.0)

**App doesn't launch at startup**
- Make sure the app lives at `/Applications/AirPodsBar.app`
- Reload the agent: `launchctl load ~/Library/LaunchAgents/com.vik.airpodsbar.plist`

**Hotkey `⌥⌘A` doesn't fire**
- Another app may have already registered this combination (rare). Quit competing apps and relaunch AirPodsBar.
- No Accessibility permission is required — uses Carbon's `RegisterEventHotKey`

---

## Project structure

```
AirPodsBar/
├── AirPodsBar.xcodeproj/
│   └── project.pbxproj
├── AirPodsBar/
│   ├── main.swift                # Entry point
│   ├── AppDelegate.swift         # Menu bar + popover + global hotkey
│   ├── BatteryMonitor.swift      # system_profiler + IOBluetooth integration
│   ├── ContentView.swift         # SwiftUI UI
│   └── AirPodsBar.entitlements   # Bluetooth permissions
└── com.vik.airpodsbar.plist      # LaunchAgent for startup
```

---

Made with ❤️ for macOS Monterey 12.7.6 and later.
