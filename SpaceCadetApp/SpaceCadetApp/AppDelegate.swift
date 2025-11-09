import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    private var tap: EventTap?
    private var remapper: KeyRemapper?
    private var enabled: Bool = true
    private let defaultHoldMs: Double = 700.0
    private let thresholdKey = "SpaceCadetHoldMs"
    private var prefsWindow: NSWindow?
    private var loggingEnabled: Bool = true
    private var adaptiveUpdateTimer: Timer?
    private let launchAtLoginKey = "SpaceCadetLaunchAtLogin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        requestAccessibilityAndStart()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopRemapper()
    }

    // MARK: - Status Bar
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = loadStatusBarIcon()
            button.toolTip = "Space Cadet"
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        menu.addItem(
            withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "Restart Event Tap", action: #selector(restartTapAction), keyEquivalent: "")
        menu.addItem(
            withTitle: "Toggle Logging", action: #selector(toggleLogging), keyEquivalent: "")
        menu.addItem(
            withTitle: "Suggest Threshold", action: #selector(suggestThreshold), keyEquivalent: "")
        menu.addItem(
            withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: currentThresholdMenuTitle(), action: nil, keyEquivalent: "")
        menu.items.last?.isEnabled = false
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Open README", action: #selector(openReadme), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Space Cadet", action: #selector(quit), keyEquivalent: "")
        menu.items.first?.state = .on
        // Reflect launch-at-login state (from manager; fallback to persisted preference)
        if let launchItem = menu.items.first(where: { $0.title == "Launch at Login" }) {
            let persisted = UserDefaults.standard.bool(forKey: launchAtLoginKey)
            let installed = LaunchAtLoginManager.isInstalled()
            let enabled = installed || persisted
            launchItem.state = enabled ? .on : .off
        }
        self.menu = menu
        statusItem.menu = menu
    }

    private func loadStatusBarIcon() -> NSImage {
        let bundle = Bundle.main
        if let img = bundle.image(forResource: "StatusBarIcon") {
            img.isTemplate = true
            return img
        } else if let img = NSImage(named: "StatusBarIcon") {
            img.isTemplate = true
            return img
        } else if #available(macOS 11.0, *) {
            let img = NSImage(
                systemSymbolName: "keyboard.badge.ellipsis",
                accessibilityDescription: "Space Cadet") ?? NSImage()
            img.isTemplate = true
            return img
        } else {
            return NSImage()
        }
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        menu.items.first?.state = enabled ? .on : .off
        if enabled { startRemapper() } else { stopRemapper() }
    }

    @objc private func openPreferences() {
        // Reuse if still valid; recreate if released or off-screen
        if let w = prefsWindow, w.isReleasedWhenClosed == false {
            if !w.isVisible { w.makeKeyAndOrderFront(nil) }
            // If window drifted off-screen (multi-display change), recenter
            if NSScreen.screens.first(where: { $0.visibleFrame.intersects(w.frame) }) == nil {
                w.center()
            }
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let current = UserDefaults.standard.double(forKey: thresholdKey)
        let initial = current > 0 ? current : defaultHoldMs
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 160),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.center()
        window.title = "SpaceCadet Preferences"
        let content = NSView(frame: window.contentView!.bounds)
        content.autoresizingMask = [.width, .height]

        let slider = NSSlider(
            value: initial, minValue: 150, maxValue: 800, target: nil, action: nil)
        slider.frame = NSRect(x: 20, y: 70, width: 300, height: 24)
        slider.isContinuous = true

        let label = NSTextField(labelWithString: "Hold Threshold: \(Int(initial)) ms")
        label.frame = NSRect(x: 20, y: 110, width: 300, height: 20)

        let adaptiveLabel = NSTextField(labelWithString: "Adaptive avg: collecting…")
        adaptiveLabel.frame = NSRect(x: 20, y: 40, width: 300, height: 18)
        adaptiveLabel.textColor = .secondaryLabelColor

        let saveButton = NSButton(title: "Save", target: nil, action: nil)
        saveButton.frame = NSRect(x: 250, y: 15, width: 70, height: 28)

        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        saveButton.target = self
        saveButton.action = #selector(savePreferences(_:))

        content.addSubview(label)
        content.addSubview(slider)
        content.addSubview(adaptiveLabel)
        content.addSubview(saveButton)
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        prefsWindow = window
        NSApp.activate(ignoringOtherApps: true)

        // Associate objects for later retrieval
        window.contentView?.setValue(slider, forKey: "slider")
        window.contentView?.setValue(label, forKey: "label")
        window.contentView?.setValue(adaptiveLabel, forKey: "adaptiveLabel")
        window.delegate = self
        startAdaptiveUIUpdates()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        if let label = prefsWindow?.contentView?.value(forKey: "label") as? NSTextField {
            label.stringValue = "Hold Threshold: \(Int(sender.doubleValue)) ms"
        }
    }

    @objc private func savePreferences(_ sender: NSButton) {
        guard let slider = prefsWindow?.contentView?.value(forKey: "slider") as? NSSlider else {
            return
        }
        let value = slider.doubleValue
        UserDefaults.standard.set(value, forKey: thresholdKey)
        restartRemapper(with: value)
    }

    @objc private func openReadme() {
        if let url = URL(string: "https://github.com/tslight/SpaceCadet#readme") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Launch at Login
    @objc private func toggleLaunchAtLogin() {
        guard let item = menu.items.first(where: { $0.title == "Launch at Login" }) else { return }
        let newState = item.state == .off
        item.state = newState ? .on : .off
        UserDefaults.standard.set(newState, forKey: launchAtLoginKey)
        do {
            try LaunchAtLoginManager.set(
                enabled: newState,
                executablePath: Bundle.main.executablePath
            )
            fputs("[SpaceCadetApp] launch-at-login \(newState ? "enabled" : "disabled")\n", stderr)
        } catch {
            fputs("[SpaceCadetApp] launch-at-login error: \(error)\n", stderr)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Accessibility
    private func requestAccessibilityAndStart() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        if AXIsProcessTrustedWithOptions(opts) {
            startRemapper()
        } else {
            // Poll briefly until granted
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.requestAccessibilityAndStart()
            }
        }
    }

    // MARK: - Remapper
    private func startRemapper() {
        guard tap == nil else { return }
        let holdMs = UserDefaults.standard.double(forKey: thresholdKey)
        let effective = holdMs > 0 ? holdMs : defaultHoldMs
        let remapper = KeyRemapper(holdThresholdMs: effective)
        remapper.setLoggingEnabled(loggingEnabled)
        let tap = EventTap(remapHandler: { event in remapper.handle(event: event) })
        do {
            try tap.start()
            fputs("[SpaceCadetApp] started (threshold=\(effective) ms)\n", stderr)
            self.remapper = remapper
            self.tap = tap
            updateThresholdMenuTitle(effective)
        } catch {
            fputs("[SpaceCadetApp] failed to start event tap: \(error)\n", stderr)
        }
    }

    private func stopRemapper() {
        // Removing run loop source is enough (EventTap manages its own source). Dropping references stops it.
        tap = nil
        remapper = nil
        fputs("[SpaceCadetApp] stopped\n", stderr)
    }

    private func restartRemapper(with newHoldMs: Double) {
        stopRemapper()
        // Clear lingering state and start with new threshold
        let remapper = KeyRemapper(holdThresholdMs: newHoldMs)
        remapper.setLoggingEnabled(loggingEnabled)
        let tap = EventTap(remapHandler: { event in remapper.handle(event: event) })
        do {
            try tap.start()
            fputs("[SpaceCadetApp] restarted (threshold=\(newHoldMs) ms)\n", stderr)
            self.remapper = remapper
            self.tap = tap
            updateThresholdMenuTitle(newHoldMs)
        } catch {
            fputs("[SpaceCadetApp] failed to restart event tap: \(error)\n", stderr)
        }
    }

    // MARK: - Menu Helpers
    private func currentThresholdMenuTitle() -> String {
        let holdMs = UserDefaults.standard.double(forKey: thresholdKey)
        let effective = holdMs > 0 ? holdMs : defaultHoldMs
        return "Threshold: \(Int(effective)) ms"
    }

    private func updateThresholdMenuTitle(_ value: Double) {
        if let item = menu.items.first(where: { $0.title.starts(with: "Threshold:") }) {
            item.title = "Threshold: \(Int(value)) ms"
        }
    }

    @objc private func restartTapAction() {
        let holdMs = UserDefaults.standard.double(forKey: thresholdKey)
        let effective = holdMs > 0 ? holdMs : defaultHoldMs
        restartRemapper(with: effective)
    }

    @objc private func toggleLogging() {
        loggingEnabled.toggle()
        fputs("[SpaceCadetApp] logging \(loggingEnabled ? "enabled" : "disabled")\n", stderr)
        remapper?.setLoggingEnabled(loggingEnabled)
    }

    @objc private func suggestThreshold() {
        guard let r = remapper, r.adaptiveCount > 5 else {
            fputs("[SpaceCadetApp] insufficient samples for suggestion (need >5)\n", stderr)
            return
        }
        let avgMs = r.adaptiveAvgTap * 1000
        let suggested = min(max(Int(avgMs + 35), 150), 800)  // avg + buffer
        fputs(
            "[SpaceCadetApp] suggested threshold ≈ \(suggested) ms (avg=\(Int(avgMs)) ms)\n", stderr
        )
    }

    // MARK: - Adaptive UI Updates
    private func startAdaptiveUIUpdates() {
        adaptiveUpdateTimer?.invalidate()
        adaptiveUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self,
                let r = self.remapper,
                let cv = self.prefsWindow?.contentView,
                let label = cv.value(forKey: "adaptiveLabel") as? NSTextField
            else { return }
            if r.adaptiveCount > 0 {
                let ms = Int(r.adaptiveAvgTap * 1000)
                label.stringValue = "Adaptive avg: ~\(ms) ms (samples=\(r.adaptiveCount))"
            }
        }
        adaptiveUpdateTimer?.fire()
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        adaptiveUpdateTimer?.invalidate()
        adaptiveUpdateTimer = nil
        if let window = notification.object as? NSWindow, window == prefsWindow {
            // Keep reference only if releasedWhenClosed is false; set to nil if it's gone
            if window.isReleasedWhenClosed {
                prefsWindow = nil
            }
        }
    }
}
