// Compile-time opt-in. This file is experimental and disabled by default.
#if HID_ENGINE_EXPERIMENTAL
    import Foundation
    import IOKit.hid

    // Forward declarations for IOHIDUserDevice (not exposed in Swift automatically)
    @_silgen_name("IOHIDUserDeviceCreate")
    private func IOHIDUserDeviceCreate(_ allocator: CFAllocator?, _ properties: CFDictionary?)
        -> IOHIDUserDevice?
    @_silgen_name("IOHIDUserDeviceHandleReport")
    private func IOHIDUserDeviceHandleReport(
        _ device: IOHIDUserDevice, _ report: UnsafeMutableRawPointer, _ reportLength: CFIndex
    ) -> IOReturn

    // MARK: - IOHID-based SpaceCadet
    final class HIDEngine {
        private var manager: IOHIDManager!
        private var virtualDevice: IOHIDUserDevice?
        private let holdThreshold: TimeInterval
        private let logEnabled = (ProcessInfo.processInfo.environment["SPACE_CADET_LOG"] != nil)

        // Physical keyboard state (usages pressed)
        private var pressedUsages = Set<UInt8>()

        // Space tap/hold state
        private enum SpaceState {
            case idle
            case pendingTap(downAt: TimeInterval)
            case holding
        }
        private var state: SpaceState = .idle
        private var holdTimer: DispatchSourceTimer?
        private var injectTapSpace = false

        // Constants
        private let usagePageKeyboard: UInt32 = 0x07
        private let usageSpace: UInt8 = 0x2C
        private let modLeftCtrlBit: UInt8 = 0x01  // bit0

        init(holdThresholdMs: Double) {
            self.holdThreshold = holdThresholdMs / 1000.0
        }

        func start() throws {
            setupManager()
            try createVirtualKeyboard()
            IOHIDManagerScheduleWithRunLoop(
                manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
            let openRes = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            if openRes != kIOReturnSuccess { throw err("IOHIDManagerOpen failed", code: openRes) }
            log("HID engine ready.")
        }

        private func setupManager() {
            manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            let match: [String: Any] = [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
            ]
            IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)

            IOHIDManagerRegisterDeviceMatchingCallback(
                manager, { ctx, result, _, device in
                    guard result == kIOReturnSuccess, let ctx = ctx else { return }
                    let this = Unmanaged<HIDEngine>.fromOpaque(ctx).takeUnretainedValue()
                    IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
                    this.log("Seized device")
                }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))

            IOHIDManagerRegisterInputValueCallback(
                manager, { ctx, result, _, value in
                    guard result == kIOReturnSuccess, let ctx = ctx else { return }
                    let this = Unmanaged<HIDEngine>.fromOpaque(ctx).takeUnretainedValue()
                    this.handle(value: value)
                }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        }

        private func createVirtualKeyboard() throws {
            let descriptor: [UInt8] = [
                0x05, 0x01,  // Usage Page (Generic Desktop)
                0x09, 0x06,  // Usage (Keyboard)
                0xA1, 0x01,  // Collection (Application)
                0x05, 0x07,  //   Usage Page (Keyboard/Keypad)
                0x19, 0xE0, 0x29, 0xE7, 0x15, 0x00, 0x25, 0x01,
                0x75, 0x01, 0x95, 0x08, 0x81, 0x02,  // 8 modifier bits
                0x95, 0x01, 0x75, 0x08, 0x81, 0x01,  // 1 byte padding
                0x95, 0x06, 0x75, 0x08, 0x15, 0x00, 0x26, 0xA4, 0x00,
                0x05, 0x07, 0x19, 0x00, 0x29, 0xA4, 0x81, 0x00,
                0xC0
            ]
            let props: [String: Any] = [
                kIOHIDReportDescriptorKey as String: Data(descriptor),
                kIOHIDVendorIDKey as String: 0x0F00,
                kIOHIDProductIDKey as String: 0x0F01,
                kIOHIDManufacturerKey as String: "SpaceCadet",
                kIOHIDProductKey as String: "SpaceCadet Virtual Keyboard",
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
            ]
            guard let vd = IOHIDUserDeviceCreate(kCFAllocatorDefault, props as CFDictionary) else {
                throw err("IOHIDUserDeviceCreate failed", code: kIOReturnError)
            }
            virtualDevice = vd
            log("Virtual keyboard created")
        }

        private func handle(value: IOHIDValue) {
            let element = IOHIDValueGetElement(value)
            let page = IOHIDElementGetUsagePage(element)
            guard page == usagePageKeyboard else { return }
            let usage = UInt8(truncatingIfNeeded: IOHIDElementGetUsage(element))
            let pressed = IOHIDValueGetIntegerValue(value) != 0

            if usage == usageSpace {
                if pressed { spaceDown() } else { spaceUp() }
            } else {
                if pressed { pressedUsages.insert(usage) } else { pressedUsages.remove(usage) }
                if case .pendingTap(let t0) = state {
                    // Any other key before threshold -> treat as hold immediately
                    if monotonicNow() - t0 < holdThreshold { transitionToHold() }
                }
            }
            updateVirtualReport()
        }

        private func spaceDown() {
            if case .holding = state { return }
            state = .pendingTap(downAt: monotonicNow())
            scheduleHoldTimer()
            log("space down -> pendingTap")
        }

        private func spaceUp() {
            cancelHoldTimer()
            switch state {
            case .pendingTap(let t0):
                // Tap if before threshold and no other keys pressed
                if monotonicNow() - t0 < holdThreshold && pressedUsages.isEmpty {
                    injectTapSpace = true
                    // Remove after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                        self?.injectTapSpace = false
                        self?.updateVirtualReport()
                    }
                    log("space tap")
                }
                state = .idle
            case .holding:
                state = .idle
                log("space up -> release control")
            case .idle:
                break
            }
            updateVirtualReport()
        }

        private func transitionToHold() {
            state = .holding
            cancelHoldTimer()
            log("transition -> holding (control)")
        }

        private func updateVirtualReport() {
            var modifiers: UInt8 = 0
            if case .holding = state { modifiers |= modLeftCtrlBit }

            // Compose keys: physical pressed excluding space, plus injected tap space if any
            var keys = [UInt8]()
            for u in pressedUsages where u != usageSpace { keys.append(u) }
            if injectTapSpace { keys.insert(usageSpace, at: 0) }
            // Trim to 6 keys
            if keys.count > 6 { keys = Array(keys.prefix(6)) }
            send(modifiers: modifiers, keys: keys)
        }

        private func scheduleHoldTimer() {
            cancelHoldTimer()
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + holdThreshold)
            timer.setEventHandler { [weak self] in self?.onHoldTimer() }
            holdTimer = timer
            timer.resume()
        }

        private func onHoldTimer() {
            if case .pendingTap(let t0) = state, monotonicNow() - t0 >= holdThreshold {
                transitionToHold()
                updateVirtualReport()
            }
        }

        private func cancelHoldTimer() {
            holdTimer?.cancel()
            holdTimer = nil
        }

        private func send(modifiers: UInt8, keys: [UInt8]) {
            var report = [UInt8](repeating: 0, count: 8)
            report[0] = modifiers
            for i in 0..<min(6, keys.count) { report[2 + i] = keys[i] }
            if let vd = virtualDevice {
                let res = report.withUnsafeBytes { raw in
                    IOHIDUserDeviceHandleReport(
                        vd, UnsafeMutableRawPointer(mutating: raw.baseAddress!), report.count)
                }
                if res != kIOReturnSuccess {
                    log("report send failed: \(String(format: "%x", res))")
                }
            }
        }

        private func monotonicNow() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
        private func err(_ msg: String, code: kern_return_t) -> NSError {
            NSError(
                domain: "HIDEngine", code: Int(code), userInfo: [NSLocalizedDescriptionKey: msg])
        }
        private func log(_ msg: String) { if logEnabled { fputs("[HID] \(msg)\n", stderr) } }
    }

#endif
