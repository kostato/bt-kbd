# bt-kbd

Use your Mac's physical keyboard to type into any iOS app over Bluetooth Low Energy. No cables, no pairing ceremony beyond the initial setup — just switch to the bt-kbd keyboard on your iPhone and every key you press on your Mac appears in the active iOS text field.

Built for cases where an app exists only on iOS and iPhone Mirroring isn't an option — so you can type comfortably on a real keyboard instead of a phone screen.

## How it works

```
Mac (BLE peripheral)  ──────────────────────►  iPhone (BLE central)
  KeyEventCapture           BLE notify            BLEKeyboardReceiver
  catches NSEvent                                 decodes packet
        │                                                │
  BLEPeripheralManager                         KeyboardViewController
  encodes & sends                              calls textDocumentProxy
```

1. **Mac app** — advertises a custom BLE GATT service and captures keyboard events system-wide using `NSEvent` local and global monitors. Each keystroke is encoded into a compact packet (one tag byte + UTF-8 payload for text; a single byte for special keys) and sent as a BLE notification.

2. **iOS keyboard extension** — subscribes to the BLE characteristic. When a packet arrives it decodes the `KeystrokeEvent` and feeds it to `UITextDocumentProxy` — the same API a normal software keyboard uses — so it works in any app without special integration.

3. **iOS companion app** — a minimal host app required by App Store rules for keyboard extensions. It shows setup instructions and a deep link to Keyboard Settings.

### BLE protocol

Defined in `Shared/BTKbdProtocol.swift`, shared between the Mac app and the keyboard extension:

| First byte | Meaning |
|---|---|
| `0x00` | Text — remaining bytes are UTF-8 |
| `0x01`–`0x09` | Special key (delete, return, tab, escape, arrow keys, …) |

## Security risks

bt-kbd is a personal tool and has not been hardened for use in untrusted environments. Two risks worth understanding before deploying it:

**Keystroke injection via BLE spoofing.** The keyboard extension connects to the first nearby BLE peripheral that advertises the bt-kbd service UUID. Because the UUIDs are public in this repository, any device within Bluetooth range that knows them can impersonate the Mac and inject arbitrary keystrokes into whatever app is active on the iPhone. The keyboard extension runs with Full Access, so injected input reaches any text field.

**Global keyboard capture on the Mac.** The Mac app intercepts keystrokes from all applications system-wide, including password managers and other sensitive apps. Capture starts automatically whenever the iPhone connects. If the iPhone disconnects unexpectedly, capture continues in the background until the user manually stops it.

Both risks are acceptable for personal, single-user use on a trusted network. See [`SECURITY_REVIEW.md`](SECURITY_REVIEW.md) for full findings and proposed mitigations.

## Requirements

| Component | Minimum |
|---|---|
| Mac app | macOS 14.0, Xcode 15 |
| iOS app + keyboard | iOS 16.0, Xcode 15 |
| Build tool | Ruby + `xcodeproj` gem |

Bluetooth must be enabled on both devices. The Mac app requires **Accessibility** permission (to capture global key events) and **Bluetooth** permission. The keyboard extension requires **Full Access**.

## Build

### 1. Generate the Xcode project

The project file is not committed — generate it from the script:

```sh
gem install xcodeproj   # once
ruby generate_project.rb
```

### 2. Open and build in Xcode

```sh
open bt-kbd.xcodeproj
```

Select the **bt-kbd-Mac** scheme and run it on your Mac. Select the **bt-kbd-iOS** scheme and run it on a connected iPhone (or use an Apple Silicon Mac for the simulator).

### 3. First-time iPhone setup

1. **Settings → General → Keyboard → Keyboards → Add New Keyboard… → bt-kbd → Remote Keyboard**
2. Tap the entry in the list and enable **Full Access**
3. Open any app, tap a text field, and switch to the bt-kbd keyboard (hold 🌐 and select "Remote Keyboard")
4. On your Mac, open bt-kbd — it advertises automatically and starts capturing once the iPhone connects
