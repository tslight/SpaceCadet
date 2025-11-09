import CoreGraphics
import Foundation

protocol Clock {
    func now() -> TimeInterval  // seconds
}

struct SystemClock: Clock {
    func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }  // monotonic
}

final class KeyRemapper {
    private let holdThreshold: TimeInterval  // seconds
    private let clock: Clock
    // Default logging ON; disable by setting SPACE_CADET_LOG=0
    // Logging always enabled for verbose CLI output
    // Fixed small early-chord window: if another key is pressed quickly after space, treat as chord
    private let earlyChordWindow: TimeInterval = 0.06  // 60ms

    // State machine
    private enum SpaceState {
        case idle
        case pendingTap(downAt: TimeInterval)
        case holdingControl(downAt: TimeInterval)
    }
    private var state: SpaceState = .idle

    // Track whether we've emitted synthetic Control down
    private var controlEngaged = false
    // Safety timer to recover from stuck holdingControl (e.g., missed spaceUp)
    private var safetyResetTimer: DispatchSourceTimer?

    // Timer for hold threshold
    private var holdTimer: DispatchSourceTimer?
    private var lastSpaceDown: TimeInterval = 0
    private(set) var adaptiveAvgTap: TimeInterval = 0.0
    private(set) var adaptiveCount: Int = 0
    private let graceWindow: TimeInterval = 0.015  // 15ms grace to avoid borderline misclassifications

    // KeyCodes: macOS virtual key codes
    private let kVK_Space: CGKeyCode = 49
    private let kVK_Control: CGKeyCode = 59  // left control
    private let syntheticUserDataFlag: Int64 = 0xFEED  // marker to allow synthetic events to pass through

    init(holdThresholdMs: Double, clock: Clock = SystemClock()) {
        self.holdThreshold = holdThresholdMs / 1000.0
        self.clock = clock
    }

    func handle(event: CGEvent) -> CGEvent? {
        // Pass through synthetic events we created for tap output
        let userData = event.getIntegerValueField(.eventSourceUserData)
        if userData == syntheticUserDataFlag {
            return event
        }
        let type = event.type
        switch type {
        case .keyDown:
            return handleKeyDown(event)
        case .keyUp:
            return handleKeyUp(event)
        case .flagsChanged:
            return event  // pass-through
        default:
            return event
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> CGEvent? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch keyCode {
        case Int64(kVK_Space):
            // Start timing and schedule hold timer
            let now = clock.now()
            state = .pendingTap(downAt: now)
            scheduleHoldTimer(reference: now)
            lastSpaceDown = now
            log("space down (pendingTap)")
            return nil  // swallow original space down
        default:
            switch state {
            case .pendingTap(let downAt):
                // Any key pressed while space is held triggers immediate control
                cancelHoldTimer()
                transitionToControlIfNeeded(downAt: downAt)
                return eventWithControl(from: event)
            case .holdingControl:
                return eventWithControl(from: event)
            case .idle:
                return event
            }
        }
    }

    private func handleKeyUp(_ event: CGEvent) -> CGEvent? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == Int64(kVK_Space) {
            cancelHoldTimer()
            switch state {
            case .pendingTap:
                // No chord occurred: emit a space tap
                let elapsed = clock.now() - lastSpaceDown
                synthesizeKeyDownUp(keyCode: kVK_Space)
                log("tap on spaceUp (elapsed=\(elapsed*1000)ms)")
                // Update adaptive average for future threshold suggestions
                updateAdaptive(elapsed: elapsed)
            case .holdingControl:
                // Emit control keyUp
                if controlEngaged { synthesizeControlKey(up: true) }
                log("control released")
            case .idle:
                break
            }
            state = .idle
            controlEngaged = false
            cancelSafetyResetTimer()
            return nil
        } else {
            // While holding control via space, also repost keyUp with control to keep phases consistent
            if case .holdingControl = state { return eventWithControl(from: event) }
            return event
        }
    }

    private func addControlModifier(to event: CGEvent) {
        var flags = event.flags
        flags.insert(.maskControl)
        event.flags = flags
    }

    // applyControlIfNeeded removed in simplified flow

    private func repostWithControl(from event: CGEvent) {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let isDown = (event.type == .keyDown)
        guard let newEvent = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: isDown)
        else { return }
        var flags = event.flags
        flags.insert(.maskControl)
        newEvent.flags = flags
        newEvent.setIntegerValueField(.eventSourceUserData, value: syntheticUserDataFlag)
        newEvent.post(tap: .cghidEventTap)
    }
    private func eventWithControl(from event: CGEvent) -> CGEvent? {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return nil }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let isDown = (event.type == .keyDown)
        guard let newEvent = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: isDown)
        else { return nil }
        var flags = event.flags
        flags.insert(.maskControl)
        newEvent.flags = flags
        newEvent.setIntegerValueField(.eventSourceUserData, value: syntheticUserDataFlag)
        return newEvent
    }

    private func synthesizeKeyDownUp(keyCode: CGKeyCode) {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        keyDown?.setIntegerValueField(.eventSourceUserData, value: syntheticUserDataFlag)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        keyUp?.setIntegerValueField(.eventSourceUserData, value: syntheticUserDataFlag)
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func synthesizeControlKey(up: Bool) {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        let evt = CGEvent(keyboardEventSource: src, virtualKey: kVK_Control, keyDown: !up)
        evt?.setIntegerValueField(.eventSourceUserData, value: syntheticUserDataFlag)
        evt?.post(tap: .cghidEventTap)
    }

    private func scheduleHoldTimer(reference: TimeInterval) {
        cancelHoldTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        // Apply a small grace window to prevent edge flicker
        timer.schedule(deadline: .now() + holdThreshold + graceWindow)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if case .pendingTap(let downAt) = self.state, downAt == reference {
                // Transition to holdingControl
                self.transitionToControlIfNeeded(downAt: downAt)
                let elapsed = self.clock.now() - downAt
                self.log("hold timer fired (elapsed=\(elapsed*1000)ms)")
            }
        }
        holdTimer = timer
        timer.resume()
    }

    private func cancelHoldTimer() {
        holdTimer?.cancel()
        holdTimer = nil
    }

    private func transitionToControlIfNeeded(downAt: TimeInterval) {
        if case .holdingControl = state { return }
        state = .holdingControl(downAt: downAt)
        synthesizeControlKey(up: false)
        controlEngaged = true
        scheduleSafetyReset()
        log("transition -> holdingControl")
    }

    private func scheduleSafetyReset() {
        cancelSafetyResetTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        // Reset if held more than 10 minutes without spaceUp (pathological case)
        timer.schedule(deadline: .now() + 600)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if case .holdingControl = self.state {
                self.log("safety reset triggered after prolonged hold")
                if self.controlEngaged { self.synthesizeControlKey(up: true) }
                self.state = .idle
                self.controlEngaged = false
            }
        }
        safetyResetTimer = timer
        timer.resume()
    }

    private func cancelSafetyResetTimer() {
        safetyResetTimer?.cancel()
        safetyResetTimer = nil
    }

    private var loggingEnabled: Bool = true
    func setLoggingEnabled(_ enabled: Bool) { loggingEnabled = enabled }
    private func log(_ msg: String) {
        guard loggingEnabled else { return }
        fputs("[SpaceCadet] \(msg)\n", stderr)
    }

    // Adaptive threshold suggestion: track average tap durations
    private func updateAdaptive(elapsed: TimeInterval) {
        // Exclude very long holds and ultra-short noise
        guard elapsed > 0.02 && elapsed < 0.5 else { return }
        adaptiveCount += 1
        // Exponential moving average (simple incremental mean here)
        adaptiveAvgTap += (elapsed - adaptiveAvgTap) / Double(adaptiveCount)
        let ms = Int(adaptiveAvgTap * 1000)
        log("adaptive avg tap ≈ \(ms)ms (n=\(adaptiveCount))")
    }
}
