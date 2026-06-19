import CoreBluetooth
import Foundation

protocol BLEKeyboardReceiverDelegate: AnyObject {
    func bleReceiver(_ receiver: BLEKeyboardReceiver, didReceive event: KeystrokeEvent)
    func bleReceiverDidConnect(_ receiver: BLEKeyboardReceiver)
    func bleReceiverDidDisconnect(_ receiver: BLEKeyboardReceiver)
    func bleReceiver(_ receiver: BLEKeyboardReceiver, didUpdateStatus status: String)
}

final class BLEKeyboardReceiver: NSObject {

    weak var delegate: BLEKeyboardReceiverDelegate?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?

    private let serviceUUID        = CBUUID(string: kBTKbdServiceUUID)
    private let characteristicUUID = CBUUID(string: kBTKbdCharacteristicUUID)

    func start() {
        centralManager = CBCentralManager(delegate: self, queue: .main,
                                          options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    func stop() {
        if let p = connectedPeripheral { centralManager.cancelPeripheralConnection(p) }
        centralManager.stopScan()
    }

    private func startScan() {
        guard centralManager.state == .poweredOn else { return }
        NSLog("[BLE] startScan for service \(kBTKbdServiceUUID)")
        delegate?.bleReceiver(self, didUpdateStatus: "Scanning for Mac…")
        centralManager.scanForPeripherals(withServices: [serviceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEKeyboardReceiver: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("[BLE] centralManagerDidUpdateState: \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            startScan()
        case .poweredOff:
            delegate?.bleReceiver(self, didUpdateStatus: "Bluetooth is off")
            NSLog("[BLE] Bluetooth powered off")
        case .unauthorized:
            delegate?.bleReceiver(self, didUpdateStatus: "Bluetooth not authorized")
            NSLog("[BLE] Bluetooth unauthorized — authorization: \(CBCentralManager.authorization.rawValue)")
        case .unsupported:
            NSLog("[BLE] Bluetooth unsupported")
        case .resetting:
            NSLog("[BLE] Bluetooth resetting")
        default:
            NSLog("[BLE] Bluetooth unknown state: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        NSLog("[BLE] didDiscover: \(name) (\(peripheral.identifier)) RSSI=\(RSSI)")
        delegate?.bleReceiver(self, didUpdateStatus: "Found \(name), connecting…")
        central.stopScan()
        connectedPeripheral = peripheral
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("[BLE] didConnect: \(peripheral.name ?? peripheral.identifier.uuidString)")
        delegate?.bleReceiver(self, didUpdateStatus: "Connected, discovering services…")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        NSLog("[BLE] didDisconnect: \(peripheral.name ?? peripheral.identifier.uuidString) error=\(error?.localizedDescription ?? "none")")
        connectedPeripheral = nil
        delegate?.bleReceiverDidDisconnect(self)
        delegate?.bleReceiver(self, didUpdateStatus: "Disconnected — scanning…")
        startScan()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        NSLog("[BLE] didFailToConnect: \(peripheral.name ?? peripheral.identifier.uuidString) error=\(error?.localizedDescription ?? "none")")
        connectedPeripheral = nil
        delegate?.bleReceiver(self, didUpdateStatus: "Connection failed — retrying…")
        startScan()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEKeyboardReceiver: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        NSLog("[BLE] didDiscoverServices error=\(error?.localizedDescription ?? "none") services=\(peripheral.services?.map(\.uuid.uuidString) ?? [])")
        if let error {
            delegate?.bleReceiver(self, didUpdateStatus: "Service discovery error: \(error.localizedDescription)")
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            delegate?.bleReceiver(self, didUpdateStatus: "bt-kbd service not found on peripheral")
            return
        }
        delegate?.bleReceiver(self, didUpdateStatus: "Service found, discovering characteristics…")
        peripheral.discoverCharacteristics([characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error {
            delegate?.bleReceiver(self, didUpdateStatus: "Characteristic discovery error: \(error.localizedDescription)")
            return
        }
        guard let char = service.characteristics?.first(where: { $0.uuid == characteristicUUID }) else {
            delegate?.bleReceiver(self, didUpdateStatus: "Keystroke characteristic not found")
            return
        }
        delegate?.bleReceiver(self, didUpdateStatus: "Subscribing…")
        peripheral.setNotifyValue(true, for: char)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            delegate?.bleReceiver(self, didUpdateStatus: "Subscription error: \(error.localizedDescription)")
            return
        }
        if characteristic.isNotifying {
            delegate?.bleReceiver(self, didUpdateStatus: "Connected — type on your Mac")
            delegate?.bleReceiverDidConnect(self)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value,
              let event = KeystrokeEvent.decode(from: data) else { return }
        delegate?.bleReceiver(self, didReceive: event)
    }
}
