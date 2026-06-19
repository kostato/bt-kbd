import Foundation

// Custom 128-bit UUIDs — not SIG-registered, so CBPeripheralManager accepts them on macOS.
let kBTKbdServiceUUID        = "E7D6A523-1F4B-4C2A-B891-7E3C5D0F2A64"
let kBTKbdCharacteristicUUID = "E7D6A524-1F4B-4C2A-B891-7E3C5D0F2A64"
let kBTKbdLocalName          = "bt-kbd"

// One BLE notification = one keystroke.
// Encoding: first byte is the type tag; remainder is payload.
//   0x00 + UTF-8 bytes → insert text
//   0x01 … 0x09        → special key (see SpecialKey below)
enum KeystrokeEvent {
    case characters(String)
    case specialKey(SpecialKey)

    enum SpecialKey: UInt8 {
        case delete        = 0x01
        case forwardDelete = 0x02
        case `return`      = 0x03
        case tab           = 0x04
        case escape        = 0x05
        case arrowLeft     = 0x06
        case arrowRight    = 0x07
        case arrowUp       = 0x08
        case arrowDown     = 0x09
    }

    func encode() -> Data {
        switch self {
        case .characters(let s):
            var d = Data([0x00])
            d.append(s.data(using: .utf8) ?? Data())
            return d
        case .specialKey(let k):
            return Data([k.rawValue])
        }
    }

    static func decode(from data: Data) -> KeystrokeEvent? {
        guard !data.isEmpty else { return nil }
        let tag = data[data.startIndex]
        if tag == 0x00 {
            let payload = data[data.index(after: data.startIndex)...]
            guard let s = String(data: payload, encoding: .utf8), !s.isEmpty else { return nil }
            return .characters(s)
        }
        if let sk = SpecialKey(rawValue: tag) { return .specialKey(sk) }
        return nil
    }
}
