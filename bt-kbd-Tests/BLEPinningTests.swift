import XCTest
@testable import bt_kbd

final class BLEPinningTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PeripheralPinStore.clear()
    }

    override func tearDown() {
        super.tearDown()
        PeripheralPinStore.clear()
    }

    func testLoadReturnsNilWhenNoPinSaved() {
        XCTAssertNil(PeripheralPinStore.load())
    }

    func testSaveAndLoadRoundTrip() {
        let id = UUID()
        PeripheralPinStore.save(id)
        XCTAssertEqual(PeripheralPinStore.load(), id)
    }

    func testClearRemovesPin() {
        PeripheralPinStore.save(UUID())
        PeripheralPinStore.clear()
        XCTAssertNil(PeripheralPinStore.load())
    }

    func testSaveOverwritesPreviousPin() {
        let first  = UUID()
        let second = UUID()
        PeripheralPinStore.save(first)
        PeripheralPinStore.save(second)
        XCTAssertEqual(PeripheralPinStore.load(), second)
    }
}
