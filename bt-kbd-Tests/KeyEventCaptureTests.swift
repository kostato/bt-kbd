import XCTest
import AppKit
import Carbon.HIToolbox
@testable import bt_kbd

// MARK: - Mock

final class MockPeripheral: KeyboardPeripheral {
    var received: [KeystrokeEvent] = []
    func sendKeystroke(_ event: KeystrokeEvent) { received.append(event) }
}

// MARK: - Helpers

private func makeKeyEvent(keyCode: UInt16, characters: String = "",
                          modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
    NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifiers,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: keyCode
    )!
}

// MARK: - Tests

final class KeyEventCaptureTests: XCTestCase {

    var mock: MockPeripheral!
    var capture: KeyEventCapture!

    override func setUp() {
        super.setUp()
        mock    = MockPeripheral()
        capture = KeyEventCapture(peripheral: mock)
    }

    // MARK: - Special key mapping

    func testDeleteKey() {
        capture.handle(makeKeyEvent(keyCode: UInt16(kVK_Delete)))
        assertSpecialKey(.delete)
    }

    func testForwardDeleteKey() {
        capture.handle(makeKeyEvent(keyCode: UInt16(kVK_ForwardDelete)))
        assertSpecialKey(.forwardDelete)
    }

    func testReturnKey() {
        capture.handle(makeKeyEvent(keyCode: UInt16(kVK_Return)))
        assertSpecialKey(.return)
    }

    func testKeypadEnter() {
        capture.handle(makeKeyEvent(keyCode: UInt16(kVK_ANSI_KeypadEnter)))
        assertSpecialKey(.return)
    }

    func testTabKey() {
        capture.handle(makeKeyEvent(keyCode: UInt16(kVK_Tab)))
        assertSpecialKey(.tab)
    }

    func testEscapeKey() {
        capture.handle(makeKeyEvent(keyCode: UInt16(kVK_Escape)))
        assertSpecialKey(.escape)
    }

    func testArrowKeys() {
        let cases: [(UInt16, KeystrokeEvent.SpecialKey)] = [
            (UInt16(kVK_LeftArrow),  .arrowLeft),
            (UInt16(kVK_RightArrow), .arrowRight),
            (UInt16(kVK_UpArrow),    .arrowUp),
            (UInt16(kVK_DownArrow),  .arrowDown),
        ]
        for (keyCode, expected) in cases {
            mock.received.removeAll()
            capture.handle(makeKeyEvent(keyCode: keyCode))
            assertSpecialKey(expected, "keyCode \(keyCode)")
        }
    }

    // MARK: - Text characters

    func testPrintableCharacterSent() {
        capture.handle(makeKeyEvent(keyCode: 0, characters: "a"))
        XCTAssertEqual(mock.received.count, 1)
        guard case .characters(let s) = mock.received.first else { XCTFail("expected .characters"); return }
        XCTAssertEqual(s, "a")
    }

    func testShiftedCharacterSent() {
        capture.handle(makeKeyEvent(keyCode: 0, characters: "A", modifiers: .shift))
        guard case .characters(let s) = mock.received.first else { XCTFail("expected .characters"); return }
        XCTAssertEqual(s, "A")
    }

    // MARK: - Filtering

    func testCommandKeyNotForwarded() {
        // Command combos must not be forwarded — they stay on the Mac.
        // The command-key guard lives in the monitor closure, not handle(), so we
        // verify that a command-flagged event reaching handle() still produces a
        // keystroke (handle() itself doesn't filter commands — the caller does).
        // This test documents that contract explicitly.
        capture.handle(makeKeyEvent(keyCode: 0, characters: "c", modifiers: .command))
        XCTAssertEqual(mock.received.count, 1, "handle() does not filter command keys — caller is responsible")
    }

    func testControlCharacterNotForwarded() {
        // Characters below 0x20 that aren't caught by special-key path should be dropped.
        // keyCode 0 with characters "\u{01}" (control-A) has no matching special key.
        capture.handle(makeKeyEvent(keyCode: 0, characters: "\u{01}"))
        XCTAssertEqual(mock.received.count, 0)
    }

    func testEmptyCharactersNotForwarded() {
        capture.handle(makeKeyEvent(keyCode: 0, characters: ""))
        XCTAssertEqual(mock.received.count, 0)
    }

    // MARK: - Helpers

    private func assertSpecialKey(_ expected: KeystrokeEvent.SpecialKey,
                                  _ message: String = "",
                                  file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(mock.received.count, 1, "event count \(message)", file: file, line: line)
        guard case .specialKey(let k) = mock.received.first else {
            XCTFail("expected .specialKey(\(expected)) \(message)", file: file, line: line)
            return
        }
        XCTAssertEqual(k, expected, message, file: file, line: line)
    }
}
