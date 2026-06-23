import AppKit
import Carbon.HIToolbox

protocol KeyEventCaptureDelegate: AnyObject {
    func keyCapture(_ capture: KeyEventCapture, didSend event: KeystrokeEvent)
}

final class KeyEventCapture {

    weak var delegate: KeyEventCaptureDelegate?

    private let peripheral: KeyboardPeripheral
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(peripheral: KeyboardPeripheral) {
        self.peripheral = peripheral
    }

    // MARK: - Start / Stop

    func start() {
        guard localMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.keyDown]

        // Local monitor: consume non-Command keystrokes so they don't also
        // fire in the currently focused Mac app. Command combos pass through
        // so Cmd+C / Cmd+Tab / etc. still work normally on the Mac.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            if event.modifierFlags.contains(.command) { return event }
            self.handle(event)
            return nil
        }

        // Global monitor fires when a different Mac app has focus.
        // Cannot consume events; used so typing in any app forwards to iPhone.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            if event.modifierFlags.contains(.command) { return }
            self?.handle(event)
        }
    }

    func stop() {
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor  = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }

    // MARK: - Event translation

    func handle(_ event: NSEvent) {
        // Special keys identified by hardware key code
        if let sk = specialKey(for: event.keyCode) {
            let e = KeystrokeEvent.specialKey(sk)
            peripheral.sendKeystroke(e)
            delegate?.keyCapture(self, didSend: e)
            return
        }

        // Printable characters — NSEvent.characters already applies the
        // correct shift / dead-key / input-method transformations.
        guard let chars = event.characters, !chars.isEmpty else { return }

        // Filter bare control characters (< 0x20) that aren't real text.
        // Tab (0x09) and newline (0x0A) are caught by the special-key path above.
        let printable = chars.unicodeScalars.contains { $0.value >= 0x20 }
        guard printable else { return }

        let e = KeystrokeEvent.characters(chars)
        peripheral.sendKeystroke(e)
        delegate?.keyCapture(self, didSend: e)
    }

    private func specialKey(for keyCode: UInt16) -> KeystrokeEvent.SpecialKey? {
        switch Int(keyCode) {
        case kVK_Delete:        return .delete
        case kVK_ForwardDelete: return .forwardDelete
        case kVK_Return, kVK_ANSI_KeypadEnter: return .return
        case kVK_Tab:           return .tab
        case kVK_Escape:        return .escape
        case kVK_LeftArrow:     return .arrowLeft
        case kVK_RightArrow:    return .arrowRight
        case kVK_UpArrow:       return .arrowUp
        case kVK_DownArrow:     return .arrowDown
        default:                return nil
        }
    }
}
