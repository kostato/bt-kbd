import XCTest
@testable import bt_kbd_Mac

final class KeystrokeEventTests: XCTestCase {

    // MARK: - Text

    func testTextRoundTrip() throws {
        let event = KeystrokeEvent.characters("hello")
        let decoded = try XCTUnwrap(KeystrokeEvent.decode(from: event.encode()))
        guard case .characters(let s) = decoded else { XCTFail("expected .characters"); return }
        XCTAssertEqual(s, "hello")
    }

    func testTextEncodingLeadByte() {
        let data = KeystrokeEvent.characters("A").encode()
        XCTAssertEqual(data.first, 0x00)
    }

    func testMultibyteUTF8RoundTrip() throws {
        let original = "こんにちは"
        let event = KeystrokeEvent.characters(original)
        let decoded = try XCTUnwrap(KeystrokeEvent.decode(from: event.encode()))
        guard case .characters(let s) = decoded else { XCTFail("expected .characters"); return }
        XCTAssertEqual(s, original)
    }

    func testEmojiRoundTrip() throws {
        let original = "👋"
        let decoded = try XCTUnwrap(KeystrokeEvent.decode(from: KeystrokeEvent.characters(original).encode()))
        guard case .characters(let s) = decoded else { XCTFail("expected .characters"); return }
        XCTAssertEqual(s, original)
    }

    // MARK: - Special keys

    func testAllSpecialKeysRoundTrip() throws {
        let keys: [KeystrokeEvent.SpecialKey] = [
            .delete, .forwardDelete, .return, .tab, .escape,
            .arrowLeft, .arrowRight, .arrowUp, .arrowDown,
        ]
        for key in keys {
            let encoded = KeystrokeEvent.specialKey(key).encode()
            let decoded = try XCTUnwrap(KeystrokeEvent.decode(from: encoded), "failed for \(key)")
            guard case .specialKey(let k) = decoded else { XCTFail("expected .specialKey for \(key)"); continue }
            XCTAssertEqual(k, key)
        }
    }

    func testSpecialKeyEncodingIsSingleByte() {
        XCTAssertEqual(KeystrokeEvent.specialKey(.delete).encode().count, 1)
    }

    func testSpecialKeyRawValues() {
        XCTAssertEqual(KeystrokeEvent.SpecialKey.delete.rawValue,        0x01)
        XCTAssertEqual(KeystrokeEvent.SpecialKey.forwardDelete.rawValue, 0x02)
        XCTAssertEqual(KeystrokeEvent.SpecialKey.return.rawValue,        0x03)
        XCTAssertEqual(KeystrokeEvent.SpecialKey.tab.rawValue,           0x04)
        XCTAssertEqual(KeystrokeEvent.SpecialKey.escape.rawValue,        0x05)
        XCTAssertEqual(KeystrokeEvent.SpecialKey.arrowLeft.rawValue,     0x06)
        XCTAssertEqual(KeystrokeEvent.SpecialKey.arrowRight.rawValue,    0x07)
        XCTAssertEqual(KeystrokeEvent.SpecialKey.arrowUp.rawValue,       0x08)
        XCTAssertEqual(KeystrokeEvent.SpecialKey.arrowDown.rawValue,     0x09)
    }

    // MARK: - Decode edge cases

    func testDecodeEmptyDataReturnsNil() {
        XCTAssertNil(KeystrokeEvent.decode(from: Data()))
    }

    func testDecodeUnknownTagReturnsNil() {
        XCTAssertNil(KeystrokeEvent.decode(from: Data([0xFF])))
    }

    func testDecodeTextWithEmptyPayloadReturnsNil() {
        // Tag 0x00 with no following bytes — empty string, should return nil
        XCTAssertNil(KeystrokeEvent.decode(from: Data([0x00])))
    }
}
