<div align="center">
  <img src="Assets/icon.png" width="128" alt="AirPodsBar Icon">
  <h1>AirPodsBar</h1>
  <p>A lightweight, native macOS menu bar app for real-time AirPods Pro battery monitoring.</p>

  <img src="https://img.shields.io/badge/macOS-12.0+-blue?logo=apple" alt="macOS 12+">
  <img src="https://img.shields.io/badge/Swift-5-orange?logo=swift" alt="Swift 5">
  <img src="https://img.shields.io/badge/architecture-Intel%20%7C%20Apple%20Silicon-lightgrey" alt="Universal">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/badge/no%20dependencies-✓-brightgreen" alt="No dependencies">
</div>

---

## Overview

AirPodsBar sits quietly in your macOS menu bar and shows you the battery level of your AirPods Pro — left earbud, right earbud, and charging case — at a glance. No Electron, no Homebrew, no subscriptions. Just a tiny native app built with Swift and SwiftUI.

<div align="center">
  <img src="Assets/menubar.png" alt="AirPodsBar in the menu bar" width="200">
</div>

---

## Features

- **Real-time battery levels** for left earbud, right earbud, and charging case
- **In-case detection** — earbuds show a green indicator when tucked in the case
- **Dynamic tooltip** — hover the menu bar icon to see all battery levels instantly, without clicking
- **Low battery alerts** — native macOS notifications when any component drops below 20%
- **Dark / Light theme** — toggle with one click, preference saved automatically
- **Connect / Disconnect** — pair or unpair your AirPods directly from the menu
- **Launch at login** — toggle in the UI, no Terminal required
- **Instant refresh** — data updates every 30 seconds and immediately when you open the menu
- **Graceful shutdown** — timers and monitors stop cleanly when the app exits
- **Zero dependencies** — uses native `IOBluetooth` and `system_profiler`, no Homebrew required

---

## Download

### Option A — Pre-built App (recommended)

Download the latest `AirPodsBar.zip` from the [**Releases**](../../releases/latest) page, unzip it, and drag `AirPodsBar.app` to your `/Applications` folder.

> **First launch:** Right-click → Open (required once, since the app is not notarized by Apple)

### Option B — Build from Source

**Requirements:** macOS 12+ · Xcode Command Line Tools

```bash
# 1. Install Xcode Command Line Tools (if not already installed)
xcode-select --install

# 2. Clone the repository
git clone https://github.com/YOUR_USERNAME/AirPodsBar.git
cd AirPodsBar

# 3. Build and install
bash install.sh
```

The installer will:
- Auto-detect your architecture (Intel or Apple Silicon)
- Compile all Swift source files
- Create the `.app` bundle with icon
- Install to `/Applications`
- Configure launch at login

---

## How It Works

macOS exposes AirPods battery data through `system_profiler SPBluetoothDataType`. AirPodsBar parses this output every 30 seconds on a background thread and pushes updates to the SwiftUI interface on the main thread.

**Charging detection** works by comparing consecutive battery readings — if a value increases between refreshes, the component is inferred to be charging. This is the most reliable approach available without private Apple APIs.

**In-case detection** is exact: if an earbud stops reporting battery (`-1`) while the case still reports its own level, that earbud is definitively in the case.

---

## Requirements

| | |
|---|---|
| **macOS** | 12.0 Monterey or later |
| **Architecture** | Intel x86_64 or Apple Silicon arm64 |
| **AirPods** | AirPods Pro (1st or 2nd generation) |
| **Dependencies** | None |

---

## Project Structure

```
AirPodsBar/
├── AirPodsBar/
│   ├── main.swift           # App entry point
│   ├── AppDelegate.swift    # Menu bar icon, popover, notifications
│   ├── BatteryMonitor.swift # Data fetching, charging inference, alerts
│   ├── ContentView.swift    # SwiftUI interface
│   └── Assets.xcassets/     # App icon assets
├── Assets/                  # Screenshots and images for README
├── install.sh               # Build + install script
├── com.vik.airpodsbar.plist # LaunchAgent for login startup
└── README.md
```

---

## Uninstall

```bash
# Stop the app
pkill -x AirPodsBar

# Remove from Applications
rm -rf /Applications/AirPodsBar.app

# Remove launch at login
rm -f ~/Library/LaunchAgents/com.vik.airpodsbar.plist
```

---

## Known Limitations

- **Charging status** is inferred from battery delta between refreshes — not a direct hardware signal (macOS 12 does not expose this via public APIs)
- **Case battery** is only reported when at least one earbud is physically inside the case
- The app is not notarized by Apple — you must right-click → Open on first launch
- Launch at login takes effect from the next login, not immediately

---

## License

MIT — see [LICENSE](LICENSE)

---

## Author

Built by **Victor Breabin (VIK)**  
Moldova · Applied Informatics student

---

<div align="center">
  <sub>Made with ♥ and a lot of Swift</sub>
</div>
