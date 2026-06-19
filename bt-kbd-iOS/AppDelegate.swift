import UIKit
import CoreBluetooth

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // Held alive for the app lifetime solely to trigger the Bluetooth
    // permission prompt in the container app. The keyboard extension
    // cannot show system permission dialogs, so permission must be
    // granted here first.
    private var bluetoothTrigger: CBCentralManager?
    private var btDelegate = BTPermissionDelegate()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: SetupViewController())
        window?.makeKeyAndVisible()

        bluetoothTrigger = CBCentralManager(delegate: btDelegate, queue: .main,
                                            options: [CBCentralManagerOptionShowPowerAlertKey: true])
        return true
    }
}

// Minimal delegate — we only need the permission prompt to fire.
private class BTPermissionDelegate: NSObject, CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {}
}
