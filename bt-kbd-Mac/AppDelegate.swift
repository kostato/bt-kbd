import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        showWindow()
    }

    // Re-show the window when the user clicks the Dock icon while the app is running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { showWindow() }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func setupMenu() {
        let mainMenu = NSMenu()

        // App menu (title is replaced by the OS with the app name)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "About bt-kbd",
                                   action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                                   keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit bt-kbd",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))

        // Window menu (needed for standard Cmd+M miniaturize, etc.)
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(NSMenuItem(title: "Minimize",
                                      action: #selector(NSWindow.miniaturize(_:)),
                                      keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom",
                                      action: #selector(NSWindow.zoom(_:)),
                                      keyEquivalent: ""))
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let vc = MainViewController()
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "bt-kbd"
        w.contentViewController = vc
        w.center()
        w.orderFrontRegardless()
        window = w
    }
}
