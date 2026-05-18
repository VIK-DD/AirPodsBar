import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var batteryMonitor: BatteryMonitor?
    var eventMonitor: EventMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Previne instanțe multiple
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "com.vik.airpodsbar" &&
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        if !others.isEmpty { NSApp.terminate(nil); return }

        batteryMonitor = BatteryMonitor()

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 460)
        popover.behavior = .transient
        popover.animates = false

        let hostingController = NSHostingController(
            rootView: ContentView(monitor: batteryMonitor!)
        )
        hostingController.view.wantsLayer = true
        popover.contentViewController = hostingController
        self.popover = popover
        hostingController.view.layoutSubtreeIfNeeded()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon(connected: false)

        if let button = statusItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let p = self.popover, p.isShown else { return }
            self.closePopover()
        }

        batteryMonitor?.startMonitoring()

        // Actualizăm iconița + tooltip la schimbarea conexiunii
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AirPodsConnectionChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateStatusFromMonitor()
        }

        // Actualizăm iconița + tooltip la fiecare refresh de date
        // (necesar pentru tooltip "În husă" și procentul din menu bar)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AirPodsDataRefreshed"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateStatusFromMonitor()
        }

        // Stare inițială după primul refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.updateStatusFromMonitor()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Graceful shutdown — oprire curată a timer-elor
        batteryMonitor?.stopMonitoring()
        eventMonitor?.stop()
    }

    // MARK: - Update status (icon + tooltip + label)

    func updateStatusFromMonitor() {
        guard let monitor = batteryMonitor else { return }
        updateStatusIcon(
            connected: monitor.airpods.isConnected,
            airpods: monitor.airpods
        )
    }

    func updateStatusIcon(connected: Bool, airpods: AirPodsInfo? = nil) {
        guard let button = statusItem?.button else { return }

        let info = airpods ?? batteryMonitor?.airpods
        let left  = info?.leftBattery  ?? -1
        let right = info?.rightBattery ?? -1
        let caseB = info?.caseBattery  ?? -1
        let caseHasBattery = caseB >= 0
        let leftInCase  = left  < 0 && caseHasBattery
        let rightInCase = right < 0 && caseHasBattery

        // ── Tooltip dinamic complet ──
        if connected || caseHasBattery {
            var parts: [String] = []

            if connected {
                parts.append("AirPods Pro — Conectat")
            } else if caseHasBattery {
                parts.append("AirPods Pro — În husă")
            }

            // Căști — cu status "În husă" dacă e cazul
            if leftInCase {
                parts.append("Stânga: în husă")
            } else if left >= 0 {
                parts.append("Stânga: \(left)%")
            }

            if rightInCase {
                parts.append("Dreapta: în husă")
            } else if right >= 0 {
                parts.append("Dreapta: \(right)%")
            }

            if caseB >= 0 {
                parts.append("Husă: \(caseB)%")
            }

            button.toolTip = parts.joined(separator: "\n")
        } else {
            button.toolTip = "AirPods Pro — Deconectat"
        }

        // ── Procentul minim lângă iconiță (cea mai slabă cască activă) ──
        // Afișat doar când căștile sunt conectate și active (nu în husă)
        let activeBatteries = [left, right].filter { $0 >= 0 }
        if connected, let minBat = activeBatteries.min() {
            button.title = " \(minBat)%"
        } else {
            button.title = ""
        }

        // ── Iconița ──
        if connected {
            if let img = NSImage(systemSymbolName: "airpodspro",
                                 accessibilityDescription: "AirPods conectate") {
                img.isTemplate = true
                button.image = img
                button.imagePosition = .imageLeft
            }
        } else {
            // Deconectat — badge roșu cu X
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .light)
            guard let baseImg = NSImage(systemSymbolName: "airpodspro",
                                        accessibilityDescription: nil)?
                    .withSymbolConfiguration(symbolConfig) else { return }

            let baseSize = baseImg.size
            let badgeSize: CGFloat = 7.5
            let totalW = baseSize.width + badgeSize * 0.6
            let totalH = max(baseSize.height, badgeSize) + 1

            let canvas = NSImage(size: NSSize(width: totalW, height: totalH), flipped: false) { _ in
                let baseY = (totalH - baseSize.height) / 2
                NSColor.labelColor.set()
                baseImg.draw(in: NSRect(x: 0, y: baseY,
                                        width: baseSize.width, height: baseSize.height),
                             from: .zero, operation: .sourceOver, fraction: 1.0)

                let bx = totalW - badgeSize
                let by = totalH - badgeSize - 0.5

                // Inel contrast
                NSColor.windowBackgroundColor.withAlphaComponent(0.85).setFill()
                NSBezierPath(ovalIn: NSRect(x: bx-1.2, y: by-1.2,
                                             width: badgeSize+2.4, height: badgeSize+2.4)).fill()
                // Cerc roșu
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: NSRect(x: bx, y: by,
                                             width: badgeSize, height: badgeSize)).fill()
                // X alb
                NSColor.white.setStroke()
                let p: CGFloat = 1.7
                let x = NSBezierPath()
                x.lineWidth = 1.3
                x.lineCapStyle = .round
                x.move(to: NSPoint(x: bx+p, y: by+p))
                x.line(to: NSPoint(x: bx+badgeSize-p, y: by+badgeSize-p))
                x.move(to: NSPoint(x: bx+badgeSize-p, y: by+p))
                x.line(to: NSPoint(x: bx+p, y: by+badgeSize-p))
                x.stroke()
                return true
            }
            canvas.isTemplate = false
            button.image = canvas
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    // MARK: - Popover

    @objc func togglePopover() {
        guard let popover = popover else { return }
        if popover.isShown { closePopover() } else { openPopover() }
    }

    func openPopover() {
        guard let button = statusItem?.button else { return }
        // Show instantly with existing data — zero lag on open
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        eventMonitor?.start()
        // Refresh in background after popover is already visible
        if let lastUpdate = batteryMonitor?.lastUpdated,
           Date().timeIntervalSince(lastUpdate) > 20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.batteryMonitor?.refresh()
            }
        }
    }

    func closePopover() {
        popover?.performClose(nil)
        eventMonitor?.stop()
    }
}

class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask; self.handler = handler
    }
    deinit { stop() }

    func start() {
        if monitor != nil { stop() }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
