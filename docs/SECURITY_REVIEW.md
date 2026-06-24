# Security Review — bt-kbd

**Date:** 2026-06-23
**Reviewer:** Claude Sonnet 4.6
**Scope:** All Swift source files, entitlements, plists, and build configuration

---

## 1. HIGH Risk Findings

---

### H1 — Unauthenticated keystroke injection

**Location:** `bt-kbd-Keyboard/BLEKeyboardReceiver.swift:64–71`

The keyboard extension connects to the first peripheral that advertises the known service UUID and immediately subscribes to its keystroke characteristic. Because the UUIDs are now public on GitHub, any BLE-capable device within range can impersonate the Mac and inject arbitrary keystrokes into whatever app is active on the iPhone. The keyboard extension has Full Access, so it can write to any text field — this is effectively unauthenticated remote input injection.

```swift
// connects to whoever shows up first
func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, ...) {
    central.stopScan()
    connectedPeripheral = peripheral
    central.connect(peripheral, options: nil)   // no identity check
}
```

---

### H2 — Capture auto-starts on any reconnection

**Location:** `bt-kbd-Mac/MainViewController.swift:158`

When any BLE subscriber connects, the Mac immediately starts forwarding all keystrokes — including from other apps, including password fields — without requiring user confirmation:

```swift
case .connected(let name):
    ...
    if !isCapturing { startCapture() }   // fires unconditionally on every connect
```

Combined with H1, a spoofed peripheral can trigger global keyboard capture on the Mac.

---

### H3 — No packet size limit

**Location:** `Shared/BTKbdProtocol.swift:39–49`

`decode(from:)` accepts arbitrary-length data. A malicious peripheral can send very large payloads causing unbounded memory allocation in the keyboard extension process (which is already memory-constrained by iOS).

---

## 2. MEDIUM / LOW Findings

---

### M1 — Peripheral identifiers and RSSI logged to system log

**Location:** `bt-kbd-Keyboard/BLEKeyboardReceiver.swift:54, 67, 75, 83, 92, 104`

`peripheral.identifier` is a stable UUID derived from the Mac's Bluetooth hardware. RSSI values leak physical proximity. Both go to `NSLog`, readable by MDM profiles or anyone with `log stream` access on the device.

---

### M2 — No reconnection backoff

**Location:** `BLEKeyboardReceiver.swift:87–88, 94–95`

On disconnect or connection failure, `startScan()` is called immediately with no delay or retry cap. A nearby device forcing repeated disconnects creates a tight scan loop — sustained battery drain.

---

### M3 — Keystroke capture persists across disconnects

**Location:** `bt-kbd-Mac/KeyEventCapture.swift`, `MainViewController.swift`

The `.advertising` state disables the toggle button but does not call `stopCapture()`. If an iPhone disconnects while capture is active, the Mac continues intercepting all keystrokes from all apps indefinitely until the user manually stops it or a new subscriber connects.

---

## 3. Patch Suggestions

### H1 — Peripheral pinning via Keychain

On first connect, store the peripheral's identifier. On all subsequent connects, reject anything that doesn't match.

```swift
// In BLEKeyboardReceiver — add peripheral pinning
import Security

private let pinnedPeripheralKey = "com.btkbd.pinnedPeripheral"

private func pinnedIdentifier() -> UUID? {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: pinnedPeripheralKey,
        kSecReturnData: true,
    ]
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data,
          let str = String(data: data, encoding: .utf8) else { return nil }
    return UUID(uuidString: str)
}

private func pinIdentifier(_ id: UUID) {
    let data = id.uuidString.data(using: .utf8)!
    let attrs: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: pinnedPeripheralKey,
        kSecValueData: data,
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
    ]
    SecItemDelete(attrs as CFDictionary)
    SecItemAdd(attrs as CFDictionary, nil)
}

// In didDiscover:
func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, ...) {
    if let pinned = pinnedIdentifier(), peripheral.identifier != pinned {
        NSLog("[BLE] rejected unknown peripheral \(peripheral.identifier)")
        return
    }
    central.stopScan()
    connectedPeripheral = peripheral
    central.connect(peripheral, options: nil)
    if pinnedIdentifier() == nil { pinIdentifier(peripheral.identifier) }
}
```

Add a "Forget Mac" button in `SetupViewController` that calls `SecItemDelete` to clear the pin and allow re-pairing.

---

### H2 — Require explicit capture start on each new connection

```swift
// MainViewController.swift — remove the auto-start
case .connected(let name):
    setStatus(.systemGreen, "Connected to \(name)", "Ready — press Start Capturing")
    toggleButton.isEnabled = true
    // do NOT call startCapture() here
```

### H2 / M3 — Stop capture on disconnect

```swift
// In applyState
case .advertising:
    setStatus(.systemYellow, "Advertising…", "...")
    toggleButton.isEnabled = false
    if isCapturing { stopCapture() }   // add this line
```

---

### H3 — Packet size limit

```swift
// Shared/BTKbdProtocol.swift
static func decode(from data: Data) -> KeystrokeEvent? {
    guard !data.isEmpty, data.count <= 512 else { return nil }
    // existing logic...
}
```

---

### M1 — Scrub logs

```swift
private func shortID(_ peripheral: CBPeripheral) -> String {
    String(peripheral.identifier.uuidString.prefix(8))
}
// Use shortID(peripheral) in all NSLog calls; remove RSSI logging
```

---

### M2 — Reconnection backoff

```swift
private var reconnectDelay: TimeInterval = 1.0

private func scheduleReconnect() {
    DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
        self?.startScan()
    }
    reconnectDelay = min(reconnectDelay * 2, 30.0)
}

// Replace startScan() calls in didDisconnect/didFailToConnect with scheduleReconnect()
// Reset reconnectDelay = 1.0 in didConnect
```

---

## 4. Security Regression Tests

Add to `bt-kbd-Tests`:

```swift
// KeystrokeEventTests.swift
func testDecodeLargePayloadReturnsNil() {
    var data = Data([0x00])
    data.append(Data(repeating: 0x41, count: 513))  // 'A' * 513 — over limit
    XCTAssertNil(KeystrokeEvent.decode(from: data))
}

func testDecodeExactlyAtLimitSucceeds() {
    var data = Data([0x00])
    data.append(Data(repeating: 0x41, count: 511))  // 511 bytes payload = 512 total
    XCTAssertNotNil(KeystrokeEvent.decode(from: data))
}
```

```swift
// KeyEventCaptureTests.swift
func testCommandKeysNotForwardedByMonitor() {
    // Documents that the caller (monitor closure) is responsible for filtering
    // command combos before calling handle(). If handle() ever grows its own
    // command filter, this will catch regressions.
    capture.handle(makeKeyEvent(keyCode: UInt16(kVK_ANSI_C), characters: "c", modifiers: .command))
    XCTAssertEqual(mock.received.count, 1,
        "handle() does not filter — monitor closure is the command-key gatekeeper")
}
```

```swift
// BLEPinningTests.swift (new file — requires mocking Keychain or dependency injection)
func testUnknownPeripheralRejectedWhenPinned() {
    // Set up a pinned UUID, then attempt discovery with a different UUID.
    // Verify connectedPeripheral remains nil and connect() is never called.
}

func testFirstDiscoveryPinsPeripheral() {
    // Verify that on first discovery with no pin, the peripheral's UUID is stored.
}
```

---

## Risk Summary

| ID | Severity | Title | Fixed by |
|----|----------|-------|----------|
| H1 | High | Unauthenticated keystroke injection via BLE spoofing | Peripheral pinning in Keychain |
| H2 | High | Capture auto-starts on any BLE connection | Remove auto-start; stop on disconnect |
| H3 | High | No packet size limit — unbounded memory allocation | 512-byte cap in `decode(from:)` |
| M1 | Medium | Stable device identifiers and RSSI leaked to system log | Truncate/hash peripheral IDs; drop RSSI |
| M2 | Medium | No reconnection backoff — battery drain via forced disconnect | Exponential backoff with 30s cap |
| M3 | Low | Keystroke capture persists after iPhone disconnects | Stop capture in `.advertising` state |

**Priority:** H1 and H2 compound each other and should be fixed together — H1 is trivially exploitable by anyone with a BLE library and knowledge of the public UUIDs.
