import Foundation

protocol KeyboardPeripheral: AnyObject {
    func sendKeystroke(_ event: KeystrokeEvent)
}
