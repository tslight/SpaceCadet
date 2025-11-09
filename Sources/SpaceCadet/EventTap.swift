import CoreGraphics
import Foundation

enum EventTapError: Error, CustomStringConvertible {
    case cannotCreateTap
    case cannotCreateRunLoopSource
    case accessibilityMissing

    var description: String {
        switch self {
        case .cannotCreateTap: return "Unable to create CGEventTap."
        case .cannotCreateRunLoopSource: return "Unable to create CFMachPort run loop source."
        case .accessibilityMissing: return "Accessibility permissions are required."
        }
    }
}

final class EventTap {
    typealias Handler = (CGEvent) -> CGEvent?

    private let handler: Handler
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(remapHandler: @escaping Handler) {
        self.handler = remapHandler
    }

    func start() throws {
        // Note: kCGHIDEventTap intercepts at the HID level
        let mask =
            (1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue | 1
                << CGEventType.flagsChanged.rawValue)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(mask),
                callback: { _, type, event, refcon in
                    let mySelf = Unmanaged<EventTap>.fromOpaque(refcon!).takeUnretainedValue()

                    // Re-enable tap if disabled by timeout
                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        CGEvent.tapEnable(tap: mySelf.tap!, enable: true)
                        return Unmanaged.passUnretained(event)
                    }

                    if let newEvent = mySelf.handler(event) {
                        return Unmanaged.passUnretained(newEvent)
                    } else {
                        return nil
                    }
                },
                userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )
        else {
            throw EventTapError.cannotCreateTap
        }

        guard let rls = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            throw EventTapError.cannotCreateRunLoopSource
        }

        self.tap = tap
        self.runLoopSource = rls

        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}
