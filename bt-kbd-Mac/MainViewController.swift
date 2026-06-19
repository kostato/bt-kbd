import Cocoa

class MainViewController: NSViewController {

    // MARK: - UI
    private let statusCircle    = NSView()
    private let statusLabel     = NSTextField(labelWithString: "Starting…")
    private let detailLabel     = NSTextField(wrappingLabelWithString: "")
    private let toggleButton    = NSButton()
    private let lastKeyLabel    = NSTextField(labelWithString: "")
    private let instructionText = NSTextField(wrappingLabelWithString: """
        First time setup (once per iPhone):
        1. Install the bt-kbd app on your iPhone
        2. Enable the "bt-kbd" keyboard in Settings → General → Keyboard → Keyboards
        3. Enable Full Access for the bt-kbd keyboard
        4. Tap any text field, switch to the bt-kbd keyboard, and start typing here
        """)

    // MARK: - State
    private var bleManager: BLEPeripheralManager!
    private var capture: KeyEventCapture!
    private var isCapturing = false

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()

        bleManager = BLEPeripheralManager()
        bleManager.delegate = self
        capture = KeyEventCapture(peripheral: bleManager)
        capture.delegate = self
        bleManager.start()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if isCapturing { stopCapture() }
        bleManager.stop()
    }

    // MARK: - UI

    private func buildUI() {
        statusCircle.wantsLayer = true
        statusCircle.layer?.cornerRadius = 6
        statusCircle.layer?.backgroundColor = NSColor.systemGray.cgColor
        statusCircle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusCircle)

        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detailLabel)

        toggleButton.title = "Start Capturing"
        toggleButton.bezelStyle = .rounded
        toggleButton.isEnabled = false
        toggleButton.target = self
        toggleButton.action = #selector(toggleCapture)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toggleButton)

        lastKeyLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        lastKeyLabel.textColor = .systemGreen
        lastKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lastKeyLabel)

        instructionText.translatesAutoresizingMaskIntoConstraints = false
        instructionText.textColor = .secondaryLabelColor
        instructionText.font = .systemFont(ofSize: 11)
        instructionText.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.addSubview(instructionText)

        NSLayoutConstraint.activate([
            statusCircle.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            statusCircle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusCircle.widthAnchor.constraint(equalToConstant: 12),
            statusCircle.heightAnchor.constraint(equalToConstant: 12),

            statusLabel.centerYAnchor.constraint(equalTo: statusCircle.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: statusCircle.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: statusLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            toggleButton.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 16),
            toggleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            toggleButton.widthAnchor.constraint(equalToConstant: 150),

            lastKeyLabel.centerYAnchor.constraint(equalTo: toggleButton.centerYAnchor),
            lastKeyLabel.leadingAnchor.constraint(equalTo: toggleButton.trailingAnchor, constant: 16),
            lastKeyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            instructionText.topAnchor.constraint(equalTo: toggleButton.bottomAnchor, constant: 16),
            instructionText.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionText.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            instructionText.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Capture

    @objc private func toggleCapture() {
        if isCapturing { stopCapture() } else { startCapture() }
    }

    private func startCapture() {
        checkAccessibilityPermission()
        capture.start()
        isCapturing = true
        toggleButton.title = "Stop Capturing"
        detailLabel.stringValue = "Forwarding keystrokes to iPhone"
    }

    private func stopCapture() {
        capture.stop()
        isCapturing = false
        toggleButton.title = "Start Capturing"
        detailLabel.stringValue = "Capture paused"
    }

    private func checkAccessibilityPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) {
            detailLabel.stringValue = "Grant Accessibility access in System Settings, then try again"
        }
    }

    // MARK: - Status

    private func applyState(_ state: BLEPeripheralManager.State) {
        switch state {
        case .idle:
            setStatus(.systemGray,   "Idle", "")
            toggleButton.isEnabled = false

        case .advertising:
            setStatus(.systemYellow, "Advertising…",
                      "Open the bt-kbd app on your iPhone and activate the keyboard")
            toggleButton.isEnabled = false

        case .connected(let name):
            setStatus(.systemGreen, "Connected to \(name)",
                      isCapturing ? "Forwarding keystrokes" : "Ready — press Start Capturing")
            toggleButton.isEnabled = true
            if !isCapturing { startCapture() }

        case .error(let msg):
            setStatus(.systemRed, "Error", msg)
            toggleButton.isEnabled = false
        }
    }

    private func setStatus(_ color: NSColor, _ label: String, _ detail: String) {
        statusCircle.layer?.backgroundColor = color.cgColor
        statusLabel.stringValue  = label
        detailLabel.stringValue  = detail
    }
}

// MARK: - Delegates

extension MainViewController: BLEPeripheralManagerDelegate {
    func blePeripheral(_ manager: BLEPeripheralManager, didChangeState state: BLEPeripheralManager.State) {
        applyState(state)
    }
}

extension MainViewController: KeyEventCaptureDelegate {
    func keyCapture(_ capture: KeyEventCapture, didSend event: KeystrokeEvent) {
        switch event {
        case .characters(let s):
            lastKeyLabel.stringValue = s
        case .specialKey(let k):
            lastKeyLabel.stringValue = "[\(k)]"
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(clearLastKey), object: nil)
        perform(#selector(clearLastKey), with: nil, afterDelay: 0.6)
    }

    @objc private func clearLastKey() { lastKeyLabel.stringValue = "" }
}
