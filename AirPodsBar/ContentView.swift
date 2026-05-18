import SwiftUI
import AppKit

// MARK: - Theme

struct AppTheme {
    let isDark: Bool

    var bg:            Color { isDark ? Color(red:0.08,green:0.08,blue:0.12) : Color(red:0.95,green:0.95,blue:0.97) }
    var card:          Color { isDark ? Color(red:0.12,green:0.12,blue:0.18) : Color.white }
    var textPrimary:   Color { isDark ? .white                                : Color(red:0.1,green:0.1,blue:0.15) }
    var textSecondary: Color { isDark ? Color(white:0.55)                     : Color(white:0.42) }
    var rowBg:         Color { isDark ? Color(white:0.11)                     : Color(red:0.88,green:0.88,blue:0.92) }
    var buttonBg:      Color { isDark ? Color(white:0.16)                     : Color(red:0.82,green:0.82,blue:0.86) }
    var connectBg:     Color { isDark ? Color(white:0.22)                     : Color(red:0.75,green:0.75,blue:0.80) }
    var accentBlue:    Color { Color(red:0.3, green:0.6, blue:1.0) }
    var accentGreen:   Color { Color(red:0.2, green:0.85,blue:0.5) }
    var accentOrange:  Color { Color(red:1.0, green:0.6, blue:0.2) }
    var connectText:   Color { isDark ? Color.black : Color.white }
    var themeIconName: String { isDark ? "sun.min.fill" : "moon.fill" }
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject var monitor: BatteryMonitor
    @State private var pulseAnimation = false
    @State private var tick: Int = 0
    // @AppStorage salvează automat în UserDefaults — persistă între sesiuni
    @AppStorage("isDarkTheme") private var isDark: Bool = true

    var theme: AppTheme { AppTheme(isDark: isDark) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                Group {
                    if monitor.isLoading {
                        loadingView
                    } else if !monitor.airpods.isConnected && monitor.airpods.caseBattery < 0 {
                        // Complet deconectat — nici husa nu raporteaza date
                        disconnectedView
                    } else {
                        // Conectat SAU castile sunt in husa (husa are baterie)
                        batteryCards
                    }
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))

                Spacer()

                if !monitor.statusMessage.isEmpty {
                    Text(monitor.statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.accentOrange)
                        .padding(.bottom, 6)
                }

                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                settingsRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: 320, height: 460)
        .animation(.easeInOut(duration: 0.25), value: isDark)
        .onAppear { pulseAnimation = true }
        // Timer local la fiecare 5s — actualizează DOAR textul "acum Xs"
        // Nu triggere re-render pe tot ContentView (spre deosebire de @Published)
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            // Actualizăm doar când view-ul e activ (popover deschis)
            tick = (tick + 1) % 720  // reset la 1h pentru a nu creste la infinit
        }
    }

    // MARK: - Header
    // Layout: [icon + titlu + status] ---- [timp | buton temă]
    // Butonul de temă e aliniat cu textul "Actualizat acum Xs" pe aceeași linie

    var headerView: some View {
        HStack(alignment: .center, spacing: 12) {

            // Stânga: icon AirPods
            ZStack {
                Circle()
                    .fill(theme.accentBlue.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "airpodspro")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(theme.accentBlue)
            }

            // Mijloc: nume + status conectat
            VStack(alignment: .leading, spacing: 3) {
                Text(monitor.airpods.isConnected ? monitor.airpods.name : "AirPods Pro")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                HStack(spacing: 5) {
                    Circle()
                        .fill(monitor.airpods.isConnected ? theme.accentGreen : Color(white: 0.35))
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .fill(monitor.airpods.isConnected ? theme.accentGreen : Color.clear)
                                .frame(width: 6, height: 6)
                                .scaleEffect(pulseAnimation ? 1.8 : 1.0)
                                .opacity(pulseAnimation ? 0 : 0.6)
                                .animation(
                                    monitor.airpods.isConnected
                                        ? .easeOut(duration: 1.5).repeatForever(autoreverses: false)
                                        : .default,
                                    value: pulseAnimation
                                )
                        )
                    Text(
                        monitor.airpods.isConnected ? "Conectat" :
                        (monitor.airpods.caseBattery >= 0 ? "În husă" : "Deconectat")
                    )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(
                            monitor.airpods.isConnected ? theme.accentGreen :
                            (monitor.airpods.caseBattery >= 0 ? theme.accentBlue.opacity(0.8) : theme.textSecondary)
                        )
                }
            }

            Spacer()

            // Dreapta: timp actualizat + buton temă pe aceeași linie, aliniate curat
            HStack(spacing: 6) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Actualizat")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    Text(timeAgo(monitor.lastUpdated, tick: tick))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                }

                // Buton temă — mai mare (28x28) pentru a fi mai ușor de apăsat
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) { isDark.toggle() }
                }) {
                    Image(systemName: theme.themeIconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textPrimary.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(theme.rowBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(isDark ? "Schimbă pe Light" : "Schimbă pe Dark")
            }
        }
    }

    // MARK: - Battery Cards

    var batteryCards: some View {
        // Logica inCase: casca nu raporteaza baterie (-1) DAR husa are baterie
        // Asta inseamna cu certitudine ca e pusa in husa
        let caseHasBattery = monitor.airpods.caseBattery >= 0
        let leftInCase  = monitor.airpods.leftBattery  < 0 && caseHasBattery
        let rightInCase = monitor.airpods.rightBattery < 0 && caseHasBattery

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                BudCard(label: "STÂNGA", icon: "airpodpro.left",
                        battery: monitor.airpods.leftBattery,
                        charging: monitor.airpods.leftCharging,
                        inCase: leftInCase,
                        theme: theme)
                BudCard(label: "DREAPTA", icon: "airpodpro.right",
                        battery: monitor.airpods.rightBattery,
                        charging: monitor.airpods.rightCharging,
                        inCase: rightInCase,
                        theme: theme)
            }
            CaseCard(battery: monitor.airpods.caseBattery,
                     charging: monitor.airpods.caseCharging, theme: theme)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Loading / Disconnected

    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: theme.accentBlue))
                .scaleEffect(1.2)
            Text("Se caută AirPods...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var disconnectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airpodspro")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundColor(theme.textSecondary.opacity(0.4))
            VStack(spacing: 6) {
                Text("AirPods deconectate")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text("Apasă Conectează pentru a le conecta")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Bar

    var bottomBar: some View {
        HStack(spacing: 10) {
            Button(action: {
                if monitor.airpods.isConnected { monitor.disconnect() }
                else { monitor.connect() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: monitor.airpods.isConnected ? "wifi.slash" : "wifi")
                        .font(.system(size: 11, weight: .semibold))
                    Text(monitor.airpods.isConnected ? "Deconectează" : "Conectează")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(monitor.airpods.isConnected ? theme.textPrimary : theme.connectText)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(monitor.airpods.isConnected ? theme.connectBg : theme.accentBlue))
            }
            .buttonStyle(.plain)
            .disabled(!monitor.statusMessage.isEmpty)

            Button(action: { monitor.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(theme.buttonBg))
            }
            .buttonStyle(.plain)

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(theme.buttonBg))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Settings Row

    var settingsRow: some View {
        HStack {
            Image(systemName: "arrow.up.circle")
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
            Text("Pornire automată la login")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textSecondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { monitor.launchAtStartup },
                set: { _ in monitor.toggleStartup() }
            ))
            .toggleStyle(SwitchToggleStyle())
            .scaleEffect(0.75)
            .frame(width: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(theme.rowBg))
    }

    // MARK: - Helpers

    func timeAgo(_ date: Date, tick: Int) -> String {
        let d = Int(Date().timeIntervalSince(date))
        if d < 5  { return "chiar acum" }
        if d < 60 { return "acum \(d)s" }
        let m = d / 60
        if m < 60 { return "acum \(m)m" }
        return "acum \(m / 60)h"
    }
}

// MARK: - Bud Card

struct BudCard: View {
    let label: String
    let icon: String
    let battery: Int
    let charging: Bool
    let inCase: Bool   // casca nu raporteaza baterie dar husa are baterie → e in husa
    let theme: AppTheme

    var batteryColor: Color {
        if battery < 20 { return theme.accentOrange }
        if battery < 50 { return .yellow }
        return theme.accentGreen
    }

    var body: some View {
        VStack(spacing: 12) {

            // ── Iconita + indicator stare ──
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .ultraLight))
                    .foregroundColor(
                        inCase ? theme.accentBlue.opacity(0.4) :
                        (battery >= 0 ? theme.accentBlue : theme.textSecondary.opacity(0.3))
                    )
                    .frame(height: 44)

                // Cerc verde "in husa" — indicator clar, vizibil
                if inCase {
                    ZStack {
                        Circle()
                            .fill(theme.accentGreen)
                            .frame(width: 16, height: 16)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(.white)
                    }
                    .offset(x: 6, y: -4)
                }
            }

            // ── Continut card ──
            VStack(spacing: 5) {
                if inCase {
                    // Casca in husa — mesaj verde, bara subtila
                    Text("In husa")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.accentGreen)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.accentGreen.opacity(0.25))
                        .frame(height: 5)
                        .frame(maxWidth: .infinity)
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .kerning(1.2)
                } else {
                    // Casca activa — arata procentul
                    Text(battery >= 0 ? "\(battery)%" : "--")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    BatteryBar(level: battery, color: batteryColor)
                        .frame(height: 5)
                        .frame(maxWidth: .infinity)
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .kerning(1.2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            inCase ? theme.accentGreen.opacity(0.45) : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
    }
}

// MARK: - Case Card

struct CaseCard: View {
    let battery: Int
    let charging: Bool
    let theme: AppTheme

    var available: Bool { battery >= 0 }
    var batteryColor: Color {
        if charging     { return theme.accentGreen }
        if battery < 20 { return theme.accentOrange }
        if battery < 50 { return .yellow }
        return theme.accentGreen
    }

    // Mesaj informativ husă
    var caseMessage: String {
        if charging {
            if battery >= 100 { return "Complet încărcată" }
            return "Se încarcă..."
        }
        // Husa nu raportează baterie = nu e în raza Bluetooth sau e descărcată complet
        if !available { return "Husă nedetectată" }
        return ""
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                AirPodsProCaseIcon(color: available ? (charging ? theme.accentGreen : theme.accentBlue) : theme.textSecondary.opacity(0.35))
                    .frame(width: 28, height: 36)

                // Bolt mic pe iconita husei cand se incarca
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.accentGreen)
                        .padding(2)
                        .background(Circle().fill(theme.card))
                        .offset(x: 5, y: 5)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                // Header: HUSA + procent + charging
                HStack(spacing: 5) {
                    Text("HUSA")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .kerning(1.2)
                    Spacer()
                    Text(available ? "\(battery)%" : "--")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(charging ? theme.accentGreen : (available ? theme.textPrimary : theme.textSecondary))
                }

                // Bara de baterie
                if available {
                    BatteryBar(level: battery, color: batteryColor).frame(height: 6)
                }

                // Mesaj informativ
                if !caseMessage.isEmpty {
                    HStack(spacing: 3) {
                        if charging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 7))
                                .foregroundColor(theme.accentGreen)
                        }
                        Text(caseMessage)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(charging ? theme.accentGreen : theme.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(charging ? theme.accentGreen.opacity(0.4) : Color.clear,
                                     lineWidth: 1.5)
                )
        )
    }
}

// MARK: - AirPods Pro Case Icon
// Proportii naturale 0.78:1 (W:H) — exact ca husa fizica AirPods Pro 2

struct AirPodsProCaseIcon: View {
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let lw: CGFloat = max(1.2, w * 0.055)

            // Corp principal — un singur dreptunghi rotunjit
            let r: CGFloat = w * 0.24
            let bodyPath = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
                                cornerRadius: r)
            ctx.fill(bodyPath, with: .color(color.opacity(0.10)))
            ctx.stroke(bodyPath, with: .color(color),
                      style: StrokeStyle(lineWidth: lw, lineJoin: .round))

            // Linie separare capac/corp la 32% din înălțime
            let splitY = h * 0.32
            var splitLine = Path()
            splitLine.move(to: CGPoint(x: r * 0.5, y: splitY))
            splitLine.addLine(to: CGPoint(x: w - r * 0.5, y: splitY))
            ctx.stroke(splitLine, with: .color(color.opacity(0.50)),
                      style: StrokeStyle(lineWidth: lw * 0.55))

            // Fill capac (zona de sus)
            let capPath = Path(roundedRect: CGRect(x: lw/2, y: lw/2,
                                                    width: w - lw, height: splitY),
                               cornerRadius: r * 0.85)
            ctx.fill(capPath, with: .color(color.opacity(0.07)))

            // LED — punct centrat în capac
            let ledR = w * 0.065
            let ledPath = Path(ellipseIn: CGRect(
                x: w/2 - ledR, y: splitY * 0.48 - ledR,
                width: ledR * 2, height: ledR * 2))
            ctx.fill(ledPath, with: .color(color.opacity(0.90)))

            // Slot cască — oval vertical mic, centrat în corp
            let slotW = w * 0.19
            let slotH = h * 0.20
            let slotX = (w - slotW) / 2
            let slotY = splitY + (h - splitY) * 0.30
            let slotPath = Path(roundedRect: CGRect(x: slotX, y: slotY,
                                                     width: slotW, height: slotH),
                                cornerRadius: slotW / 2)
            ctx.fill(slotPath, with: .color(color.opacity(0.16)))
            ctx.stroke(slotPath, with: .color(color.opacity(0.55)),
                      style: StrokeStyle(lineWidth: lw * 0.60))
        }
        // aspectRatio 0.78 = proportiile reale ale husei — previne orice stretch
        .aspectRatio(0.78, contentMode: .fit)
    }
}

// MARK: - Battery Bar

struct BatteryBar: View {
    let level: Int
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: [color.opacity(0.75), color],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: level > 0
                           ? geo.size.width * CGFloat(min(level, 100)) / 100.0
                           : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: level)
            }
        }
    }
}
