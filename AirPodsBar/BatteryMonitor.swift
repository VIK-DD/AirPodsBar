import Foundation
import IOBluetooth
import UserNotifications

struct AirPodsInfo {
    var name: String = "AirPods Pro"
    var address: String = ""
    var isConnected: Bool = false
    var leftBattery: Int = -1
    var rightBattery: Int = -1
    var caseBattery: Int = -1
    // Charging inferit din delta baterie între refresh-uri
    var leftCharging: Bool = false
    var rightCharging: Bool = false
    var caseCharging: Bool = false
}

class BatteryMonitor: ObservableObject {
    @Published var airpods: AirPodsInfo = AirPodsInfo()
    @Published var isLoading: Bool = true
    @Published var lastUpdated: Date = Date()
    @Published var statusMessage: String = ""
    @Published var launchAtStartup: Bool = false

    private var lastConnectedState: Bool = false
    private var timer: Timer?

    // Valorile anterioare pentru detectarea charging prin delta
    private var prevLeft: Int = -1
    private var prevRight: Int = -1
    private var prevCase: Int = -1

    // Anti-spam notificări — reținem ce notificări am trimis deja
    private var notifiedLow: Set<String> = []  // "left", "right", "case"
    private var notifiedCharging: Set<String> = []

    private let plistDest: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("com.vik.airpodsbar.plist")
    }()

    private let plistContent = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vik.airpodsbar</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/AirPodsBar.app/Contents/MacOS/AirPodsBar</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
"""

    func startMonitoring() {
        launchAtStartup = FileManager.default.fileExists(atPath: plistDest.path)
        requestNotificationPermission()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        timer?.invalidate(); timer = nil
    }

    func refresh() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            var info = self.fetchAirPodsInfo()

            // Inferența charging se face pe main thread (în blocul async de jos)
            // pentru a evita race condition cu prevLeft/Right/Case

            DispatchQueue.main.async {
                let wasConnected = self.lastConnectedState

                // Inferăm charging pe main thread — citire și scriere prevValues în același context
                // Elimina race condition față de citirea de pe background thread
                if self.prevLeft  >= 0 && info.leftBattery  > self.prevLeft  { info.leftCharging  = true }
                if self.prevRight >= 0 && info.rightBattery > self.prevRight { info.rightCharging = true }
                if self.prevCase  >= 0 && info.caseBattery  > self.prevCase  { info.caseCharging  = true }

                // Actualizăm prev values după inferență
                if info.leftBattery  > 0 { self.prevLeft  = info.leftBattery }
                if info.rightBattery > 0 { self.prevRight = info.rightBattery }
                if info.caseBattery  > 0 { self.prevCase  = info.caseBattery }

                self.airpods = info
                self.isLoading = false
                self.lastUpdated = Date()

                // ── Schimbare stare conexiune ──
                if info.isConnected != wasConnected {
                    self.lastConnectedState = info.isConnected
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AirPodsConnectionChanged"), object: nil)
                    if !info.isConnected {
                        // La deconectare: resetam tot INAINTE de notificari
                        // ca sa nu trimitem notificari false cu datele vechi
                        self.notifiedLow.removeAll()
                        self.notifiedCharging.removeAll()
                        self.prevLeft = -1; self.prevRight = -1; self.prevCase = -1
                        // ConnectionChanged notifica si AppDelegate — nu trimitem DataRefreshed dublat
                        return
                    }
                }

                // ── Notificări baterie scăzută (doar dacă conectat) ──
                if info.isConnected {
                    self.checkLowBatteryNotifications(info: info)
                    self.checkChargingNotifications(info: info)
                }

                // ── Actualizează tooltip și label în menu bar ──
                NotificationCenter.default.post(
                    name: NSNotification.Name("AirPodsDataRefreshed"), object: nil)
            }
        }
    }

    // MARK: - Notificări baterie scăzută

    private func checkLowBatteryNotifications(info: AirPodsInfo) {
        let threshold = 20

        if info.leftBattery > 0 && info.leftBattery <= threshold && !info.leftCharging
            && !notifiedLow.contains("left") {
            sendNotification(
                title: "Baterie scăzută — \(info.name)",
                body: "Căsca stângă are doar \(info.leftBattery)% baterie.",
                identifier: "low_left"
            )
            notifiedLow.insert("left")
        } else if info.leftBattery > threshold {
            notifiedLow.remove("left")  // resetăm când bate s-a încărcat
        }

        if info.rightBattery > 0 && info.rightBattery <= threshold && !info.rightCharging
            && !notifiedLow.contains("right") {
            sendNotification(
                title: "Baterie scăzută — \(info.name)",
                body: "Căsca dreaptă are doar \(info.rightBattery)% baterie.",
                identifier: "low_right"
            )
            notifiedLow.insert("right")
        } else if info.rightBattery > threshold {
            notifiedLow.remove("right")
        }

        if info.caseBattery > 0 && info.caseBattery <= threshold && !info.caseCharging
            && !notifiedLow.contains("case") {
            sendNotification(
                title: "Baterie scăzută — Husă",
                body: "Husa de încărcare are doar \(info.caseBattery)% baterie.",
                identifier: "low_case"
            )
            notifiedLow.insert("case")
        } else if info.caseBattery > threshold {
            notifiedLow.remove("case")
        }
    }

    // MARK: - Notificări charging

    private func checkChargingNotifications(info: AirPodsInfo) {
        // Notificăm când o componentă ÎNCEPE să se încarce
        if info.leftCharging && !notifiedCharging.contains("left") {
            notifiedCharging.insert("left")
            sendNotification(
                title: "Se încarcă — \(info.name)",
                body: "Căsca stângă se încarcă (\(info.leftBattery)%).",
                identifier: "charging_left"
            )
        } else if !info.leftCharging {
            notifiedCharging.remove("left")
        }

        if info.rightCharging && !notifiedCharging.contains("right") {
            notifiedCharging.insert("right")
            sendNotification(
                title: "Se încarcă — \(info.name)",
                body: "Căsca dreaptă se încarcă (\(info.rightBattery)%).",
                identifier: "charging_right"
            )
        } else if !info.rightCharging {
            notifiedCharging.remove("right")
        }

        if info.caseCharging && !notifiedCharging.contains("case") {
            notifiedCharging.insert("case")
            sendNotification(
                title: "Se încarcă — Husă",
                body: "Husa de încărcare se încarcă (\(info.caseBattery)%).",
                identifier: "charging_case"
            )
        } else if !info.caseCharging {
            notifiedCharging.remove("case")
        }
    }

    // MARK: - UserNotifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            print("[AirPodsBar] Notificări permise: \(granted)")
        }
    }

    private func sendNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "airpodsbar.\(identifier)",
            content: content,
            trigger: nil  // livrat imediat
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AirPodsBar] Eroare notificare: \(error)")
            }
        }
    }

    // MARK: - system_profiler fetch

    private func fetchAirPodsInfo() -> AirPodsInfo {
        var result = AirPodsInfo()
        let output = shell("/usr/sbin/system_profiler SPBluetoothDataType")
        guard !output.isEmpty else { return result }

        let lines = output.components(separatedBy: "\n")
        var inBlock = false
        var blockIndent = 0

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !inBlock {
                if trimmed.hasSuffix(":") {
                    let name = String(trimmed.dropLast())
                    if name.lowercased().contains("airpods") {
                        inBlock = true
                        result.name = name
                        blockIndent = line.prefix(while: { $0 == " " }).count
                    }
                }
                continue
            }

            let indent = line.prefix(while: { $0 == " " }).count
            if !trimmed.isEmpty && indent <= blockIndent && i > 0 { break }

            func extractVal(_ key: String) -> Int {
                guard trimmed.hasPrefix(key) else { return -1 }
                let v = trimmed.replacingOccurrences(of: key, with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "%", with: "")
                return Int(v) ?? -1
            }

            if trimmed.hasPrefix("Left Battery Level:") {
                let v = extractVal("Left Battery Level:")
                result.leftBattery = v; if v >= 0 { result.isConnected = true }
            } else if trimmed.hasPrefix("Right Battery Level:") {
                let v = extractVal("Right Battery Level:")
                result.rightBattery = v; if v >= 0 { result.isConnected = true }
            } else if trimmed.hasPrefix("Case Battery Level:") {
                result.caseBattery = extractVal("Case Battery Level:")
            } else if trimmed.hasPrefix("Address:") {
                result.address = trimmed
                    .replacingOccurrences(of: "Address:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    // MARK: - Startup toggle

    func toggleStartup() {
        launchAtStartup ? disableStartup() : enableStartup()
    }

    private func enableStartup() {
        do {
            let dir = plistDest.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try plistContent.write(to: plistDest, atomically: true, encoding: .utf8)
            DispatchQueue.main.async { self.launchAtStartup = true }
        } catch {
            print("[AirPodsBar] enableStartup error: \(error)")
        }
    }

    private func disableStartup() {
        try? FileManager.default.removeItem(at: plistDest)
        DispatchQueue.main.async { self.launchAtStartup = false }
    }

    // MARK: - Connect / Disconnect

    func connect() {
        let addr = resolveAddress()
        guard !addr.isEmpty else { setStatus("Adresa Bluetooth nu a fost gasita."); return }
        setStatus("Se conecteaza...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let normalized = addr.replacingOccurrences(of: "-", with: ":").uppercased()
            if let device = IOBluetoothDevice(addressString: normalized) {
                let ret = device.openConnection()
                print("[AirPodsBar] openConnection() returned: \(ret)")
                Thread.sleep(forTimeInterval: 2.5)
                self.refresh()
                Thread.sleep(forTimeInterval: 1.0)
            }
            DispatchQueue.main.async { self.statusMessage = "" }
        }
    }

    func disconnect() {
        let addr = resolveAddress()
        guard !addr.isEmpty else { setStatus("Adresa Bluetooth nu a fost gasita."); return }
        setStatus("Se deconecteaza...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let normalized = addr.replacingOccurrences(of: "-", with: ":").uppercased()
            if let device = IOBluetoothDevice(addressString: normalized) {
                let ret = device.closeConnection()
                print("[AirPodsBar] closeConnection() returned: \(ret)")
            }
            Thread.sleep(forTimeInterval: 1.5)
            DispatchQueue.main.async {
                self.airpods.isConnected = false
                self.airpods.leftBattery = -1
                self.airpods.rightBattery = -1
                self.airpods.caseBattery = -1
                self.statusMessage = ""
                self.lastConnectedState = false
                self.notifiedLow.removeAll()
                self.notifiedCharging.removeAll()
                self.prevLeft = -1; self.prevRight = -1; self.prevCase = -1
                // Notificăm AppDelegate să actualizeze iconița și tooltip-ul
                NotificationCenter.default.post(
                    name: NSNotification.Name("AirPodsConnectionChanged"), object: nil)
            }
        }
    }

    private func resolveAddress() -> String {
        if !airpods.address.isEmpty { return airpods.address }
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for dev in paired {
                if let name = dev.name, name.lowercased().contains("airpods") {
                    return dev.addressString ?? ""
                }
            }
        }
        return ""
    }

    private func setStatus(_ msg: String) {
        DispatchQueue.main.async { self.statusMessage = msg }
    }

    @discardableResult
    func shell(_ command: String, timeout: Double = 10.0) -> String {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()  // stderr separat — nu polueaza output-ul

        do { try task.run() } catch { return "" }

        // Watchdog — dacă procesul blochează mai mult de timeout, îl terminăm forțat
        let deadline = DispatchTime.now() + timeout
        let result = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .utility).async {
            task.waitUntilExit()
            result.signal()
        }

        if result.wait(timeout: deadline) == .timedOut {
            task.terminate()
            print("[AirPodsBar] WATCHDOG: shell timeout după \(timeout)s — \(command.prefix(60))")
            return ""
        }

        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
