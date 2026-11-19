import ServiceManagement
import SwiftUI
import UserNotifications

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    var body: some Scene { Settings { EmptyView() } }
}

// Not using MenuBarExtra: it always puts a glass slab behind the content and
// there's no way to turn it off. A status item + our own see-through panel
// lets the tiles float on their own, like Control Center.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let model = Pomodoro()
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private lazy var panel = FloatingPanel(content: PanelView(model: model))

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 0, weight: .regular)
        updateLabel()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    // Show it even while our panel is open (app counts as frontmost then).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    // Show the time in the menu bar only while it's actually ticking.
    private func updateLabel() {
        withObservationTracking {
            item.button?.image = NSImage(systemSymbolName: model.phase.symbol, accessibilityDescription: model.phase.label)
            item.button?.title = model.isRunning ? model.timeString : ""
        } onChange: {
            DispatchQueue.main.async { self.updateLabel() }
        }
    }

    @objc private func togglePanel() {
        if panel.isVisible { return panel.close() }
        guard let button = item.button, let buttonWindow = button.window, let screen = buttonWindow.screen else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let x = min(anchor.minX - 14, screen.visibleFrame.maxX - panel.frame.width)
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: anchor.minY - 2))
        panel.makeKeyAndOrderFront(nil)
    }
}

// Borderless, transparent, content hangs from the top. Closes on Esc or a click
// outside. Not on losing focus, since the sound picker's menu steals focus too.
final class FloatingPanel: NSPanel {
    static let willClose = Notification.Name("FloatingPanel.willClose")
    private var clickOutside: Any?

    init(content: some View) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 320, height: 640),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: content.frame(maxHeight: .infinity, alignment: .top))
    }

    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        // Global monitor only sees clicks in other apps, so our own menus don't count.
        clickOutside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    override func close() {
        guard isVisible else { return }
        clickOutside.map(NSEvent.removeMonitor)
        clickOutside = nil
        NotificationCenter.default.post(name: Self.willClose, object: self)
        // Give the SwiftUI close animation a moment before the window goes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.orderOut(nil) }
    }
}

// Control Center vibe: floating glass tiles, white circle = on.
private let tileRadius: CGFloat = 26
private let spacing: CGFloat = 12
// Plain colors here, not .fill.tertiary / .primary. Those are "vibrant" and get their
// brightness from the glass behind them, so they flash dark while the glass fades in.
private let track = Color(nsColor: .quaternaryLabelColor)
private let ink = Color(nsColor: .labelColor)

struct PanelView: View {
    @Bindable var model: Pomodoro
    @State private var showSettings = false
    @State private var isOpen = false

    var body: some View {
        // The container batches all tiles into one backdrop, which is what makes the
        // transitions smooth. Spacing must stay 0: it's the distance at which tiles
        // start blending into each other, and with it near the gap size every gap
        // got a faint half-glass fill. Also never fade glass with .opacity, it flickers.
        GlassEffectContainer(spacing: 0) {
            if isOpen { panel.transition(.scale(0.94, anchor: .top)) }
        }
        .frame(width: 320)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            withAnimation(.spring(duration: 0.4, bounce: 0.25)) { isOpen = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: FloatingPanel.willClose)) { _ in
            withAnimation(.easeIn(duration: 0.2)) { isOpen = false }
        }
    }

    private var panel: some View {
        VStack(spacing: spacing) {
            Group {
                if showSettings {
                    VStack(spacing: spacing) { SettingsView(model: model) }
                } else {
                    VStack(spacing: spacing) { TimerView(model: model) }
                }
            }
            .transition(.scale(0.96))
            HStack(spacing: spacing) {
                PillButton(title: showSettings ? "Done" : "Settings") {
                    withAnimation(.smooth(duration: 0.35)) { showSettings.toggle() }
                }
                PillButton(title: "Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
    }
}

struct TimerView: View {
    let model: Pomodoro

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                IconCircle(symbol: model.phase.symbol, active: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.phase.label).font(.headline)
                    Text("Session \(model.sessionNumber) of \(model.longBreakInterval)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text(model.timeString)
                .font(.system(size: 60, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: model.timeString)
                .frame(maxWidth: .infinity)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    Capsule().fill(ink).frame(width: geo.size.width * model.progress)
                }
            }
            .frame(height: 6)
            .animation(.linear(duration: 0.25), value: model.progress)
            .accessibilityHidden(true)
        }
        .tile()

        HStack(spacing: spacing) {
            CircleButton(symbol: "arrow.counterclockwise", label: "Reset", action: model.reset)
            Button(action: model.toggle) {
                HStack(spacing: 10) {
                    IconCircle(symbol: model.isRunning ? "pause.fill" : "play.fill",
                               active: model.isRunning)
                    Text(model.isRunning ? "Pause" : "Start").font(.body.weight(.medium))
                    Spacer(minLength: 0)
                }
                .padding(12)
            }
            .buttonStyle(Pressable(shape: Capsule()))
            .keyboardShortcut(.space, modifiers: [])
            CircleButton(symbol: "forward.end.fill", label: "Skip", action: model.skip)
        }
    }
}

struct SettingsView: View {
    @Bindable var model: Pomodoro
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Durations").font(.headline)
            stepper("Focus", $model.focusMinutes, 1...120, unit: "min")
            stepper("Short break", $model.shortBreakMinutes, 1...60, unit: "min")
            stepper("Long break", $model.longBreakMinutes, 1...60, unit: "min")
            stepper("Long break every", $model.longBreakInterval, 2...10, unit: "sessions")
        }
        .tile()

        VStack(alignment: .leading, spacing: 10) {
            Text("Sound").font(.headline)
            HStack(spacing: 10) {
                Button { model.player.play(model.sound) } label: {
                    IconCircle(symbol: "speaker.wave.2.fill", size: 32)
                }
                .buttonStyle(.plain)
                .help("Preview")
                Picker("Sound", selection: $model.sound) {
                    ForEach(Sound.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
            }
        }
        .tile()
        .onChange(of: model.sound) { model.player.play(model.sound) }

        HStack(spacing: spacing) {
            ToggleTile(title: "Auto-start", symbol: "repeat", isOn: $model.autoStart)
            ToggleTile(title: "At Login", symbol: "power", isOn: $launchAtLogin)
        }
        .onChange(of: launchAtLogin) {
            try? launchAtLogin ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func stepper(_ title: String, _ value: Binding<Int>, _ range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value.wrappedValue) \(unit)").monospacedDigit().foregroundStyle(.secondary)
            Stepper(title, value: value, in: range).labelsHidden()
        }
    }
}

// MARK: - Building blocks

extension View {
    func tile() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
    }

    // Each tile is its own glass. The panel behind is transparent, so no glass-on-glass.
    // Tried .clear here, looks closer to Control Center but the buttons vanish over white.
    func surface(_ shape: some InsettableShape, interactive: Bool = false) -> some View {
        glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
    }
}

struct Pressable<S: InsettableShape>: ButtonStyle {
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
            .surface(shape, interactive: true)
    }
}

struct IconCircle: View {
    let symbol: String
    var active = false
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(active ? .black : .primary)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: active)
            .frame(width: size, height: size)
            .background(Circle().fill(active ? .white : track))
            .animation(.snappy, value: symbol)
            .animation(.snappy, value: active)
    }
}

struct CircleButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 64, height: 64)
        }
        .buttonStyle(Pressable(shape: Circle()))
        .help(label)
        .accessibilityLabel(label)
    }
}

struct ToggleTile: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 10) {
                IconCircle(symbol: symbol, active: isOn)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.headline)
                    Text(isOn ? "On" : "Off").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
        }
        .buttonStyle(Pressable(shape: Capsule()))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct PillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(Pressable(shape: Capsule()))
    }
}

