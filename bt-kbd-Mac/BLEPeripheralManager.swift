import CoreBluetooth
import Foundation

protocol BLEPeripheralManagerDelegate: AnyObject {
    func blePeripheral(_ manager: BLEPeripheralManager, didChangeState state: BLEPeripheralManager.State)
}

final class BLEPeripheralManager: NSObject {

    enum State {
        case idle
        case advertising
        case connected(deviceName: String)
        case error(String)
    }

    weak var delegate: BLEPeripheralManagerDelegate?

    private var peripheralManager: CBPeripheralManager!
    private var keystrokeCharacteristic: CBMutableCharacteristic?
    private var pendingEvent: Data?          // queued if transmit buffer was full

    private(set) var state: State = .idle {
        didSet { delegate?.blePeripheral(self, didChangeState: state) }
    }

    // MARK: - Public

    func start() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main,
                                                options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }

    func stop() {
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        state = .idle
    }
}

// MARK: - KeyboardPeripheral

extension BLEPeripheralManager: KeyboardPeripheral {
    func sendKeystroke(_ event: KeystrokeEvent) {
        guard let char = keystrokeCharacteristic else { return }
        let data = event.encode()
        let sent = peripheralManager.updateValue(data, for: char, onSubscribedCentrals: nil)
        if !sent { pendingEvent = data }   // retry in peripheralManagerIsReady
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEPeripheralManager: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            addService()
        case .poweredOff:
            state = .error("Bluetooth is off")
        case .unauthorized:
            state = .error("Bluetooth access not authorized")
        case .unsupported:
            state = .error("Bluetooth LE not supported on this Mac")
        default:
            break
        }
    }

    private func addService() {
        let serviceUUID = CBUUID(string: kBTKbdServiceUUID)
        let charUUID    = CBUUID(string: kBTKbdCharacteristicUUID)

        let characteristic = CBMutableCharacteristic(
            type: charUUID,
            properties: [.notify, .read],
            value: nil,
            permissions: .readable
        )
        keystrokeCharacteristic = characteristic

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheralManager.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            state = .error("Service error: \(error.localizedDescription)")
            return
        }
        print("✅ bt-kbd BLE service added")
        peripheral.startAdvertising([
            CBAdvertisementDataLocalNameKey:    kBTKbdLocalName,
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: kBTKbdServiceUUID)],
        ])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            state = .error("Advertising error: \(error.localizedDescription)")
        } else {
            state = .advertising
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        state = .connected(deviceName: "iPhone")
        print("✅ Central subscribed: \(central.identifier)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        state = .advertising
        print("Central unsubscribed: \(central.identifier)")
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard let char = keystrokeCharacteristic, let data = pendingEvent else { return }
        pendingEvent = nil
        peripheralManager.updateValue(data, for: char, onSubscribedCentrals: nil)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        request.value = Data()
        peripheral.respond(to: request, withResult: .success)
    }
}
