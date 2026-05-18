# 🎧 AirPodsBar

Aplicație nativă macOS pentru bara de meniu care afișează bateria AirPods Pro în timp real.

## Ce face
- Afișează bateria pentru **căștea stângă**, **căștea dreaptă** și **husă**
- Indică dacă căștile sunt **la ureche** (in-ear detection)
- Indică dacă se **încarcă**
- **Conectează / Deconectează** AirPods din aplicație
- Pornește automat la **startup**
- Se actualizează la fiecare **30 de secunde**

---

## Instalare

### Pasul 1 — Instalează blueutil (pentru connect/disconnect)
```bash
brew install blueutil
```

### Pasul 2 — Deschide proiectul în Xcode
```bash
open AirPodsBar.xcodeproj
```

### Pasul 3 — Build & Run
1. În Xcode: **Product → Run** (⌘R)
2. Prima dată va apărea o cerere de permisiuni Bluetooth — aprobă

### Pasul 4 — Mută în Applications (pentru startup)
```bash
# Build Release
# Product → Archive → Distribute App → Copy App

# Sau build direct din terminal:
xcodebuild -project AirPodsBar.xcodeproj -scheme AirPodsBar -configuration Release build

# Copiază .app în Applications
cp -R build/Release/AirPodsBar.app /Applications/
```

### Pasul 5 — Activează pornirea la startup
```bash
cp com.vik.airpodsbar.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.vik.airpodsbar.plist
```

Pentru a dezactiva startup:
```bash
launchctl unload ~/Library/LaunchAgents/com.vik.airpodsbar.plist
```

---

## Depanare

**Bateriile apar ca "--"**
- Asigură-te că AirPods sunt conectate la Mac
- Încearcă să apeși butonul Refresh (↻)
- macOS transmite datele de baterie doar când căștile sunt active

**Connect/Disconnect nu funcționează**
- Verifică că `blueutil` e instalat: `which blueutil`
- Dacă e pe Apple Silicon (M1/M2): path-ul e `/opt/homebrew/bin/blueutil`
- Dacă e pe Intel: `/usr/local/bin/blueutil`

**Aplicația nu pornește la startup**
- Verifică că app-ul e în `/Applications/AirPodsBar.app`
- Re-rulează: `launchctl load ~/Library/LaunchAgents/com.vik.airpodsbar.plist`

---

## Structura proiectului

```
AirPodsBar/
├── AirPodsBar.xcodeproj/
│   └── project.pbxproj
├── AirPodsBar/
│   ├── AirPodsBarApp.swift      # Entry point @main
│   ├── AppDelegate.swift         # Menu bar + popover management
│   ├── BatteryMonitor.swift      # IORegistry + blueutil integration
│   ├── ContentView.swift         # UI SwiftUI
│   └── AirPodsBar.entitlements  # Permisiuni Bluetooth
└── com.vik.airpodsbar.plist     # LaunchAgent pentru startup
```

---

Făcut cu ❤️ pentru macOS Monterey 12.7.6
