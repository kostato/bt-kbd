import UIKit

class KeyboardViewController: UIInputViewController {

    private var receiver: BLEKeyboardReceiver!
    private var statusLabel: UILabel!
    private var nextKeyboardButton: UIButton!
    private var forgetButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("[KB] viewDidLoad — extension is running")
        buildUI()

        receiver = BLEKeyboardReceiver()
        receiver.delegate = self
        receiver.start()
        NSLog("[KB] BLEKeyboardReceiver started")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        receiver.stop()
    }

    // MARK: - Minimal keyboard UI

    private func buildUI() {
        view.backgroundColor = .systemGroupedBackground

        // Globe/switch button — tap switches to next keyboard, long-press shows picker
        nextKeyboardButton = UIButton(type: .system)
        nextKeyboardButton.setTitle("🌐", for: .normal)
        nextKeyboardButton.titleLabel?.font = .systemFont(ofSize: 20)
        nextKeyboardButton.addTarget(self,
                                     action: #selector(handleInputModeList(from:with:)),
                                     for: .allTouchEvents)
        nextKeyboardButton.isHidden = !needsInputModeSwitchKey
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextKeyboardButton)

        // Always-visible "ABC" button that advances to the next input mode directly
        let switchButton = UIButton(type: .system)
        switchButton.setTitle("ABC", for: .normal)
        switchButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        switchButton.backgroundColor = .systemBackground
        switchButton.layer.cornerRadius = 6
        switchButton.layer.shadowColor = UIColor.black.cgColor
        switchButton.layer.shadowOpacity = 0.25
        switchButton.layer.shadowRadius = 1
        switchButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        switchButton.addTarget(self, action: #selector(switchKeyboard), for: .touchUpInside)
        switchButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(switchButton)

        statusLabel = UILabel()
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.text = "Starting…"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        forgetButton = UIButton(type: .system)
        forgetButton.setTitle("Forget Mac", for: .normal)
        forgetButton.titleLabel?.font = .systemFont(ofSize: 12)
        forgetButton.setTitleColor(.systemRed, for: .normal)
        forgetButton.addTarget(self, action: #selector(forgetMac), for: .touchUpInside)
        forgetButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(forgetButton)

        let height = view.heightAnchor.constraint(equalToConstant: 100)
        height.priority = UILayoutPriority(999)
        height.isActive = true

        NSLayoutConstraint.activate([
            nextKeyboardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            switchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            switchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            switchButton.widthAnchor.constraint(equalToConstant: 56),
            switchButton.heightAnchor.constraint(equalToConstant: 34),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: nextKeyboardButton.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: switchButton.leadingAnchor, constant: -8),

            forgetButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            forgetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ])
    }

    @objc private func switchKeyboard() {
        advanceToNextInputMode()
    }

    @objc private func forgetMac() {
        receiver.forgetAndRescan()
        statusLabel.text = "Scanning for new Mac…"
        statusLabel.textColor = .secondaryLabel
    }

    // MARK: - Apply keystroke to the document proxy

    private func apply(_ event: KeystrokeEvent) {
        let proxy = textDocumentProxy
        switch event {
        case .characters(let s):
            proxy.insertText(s)
        case .specialKey(let sk):
            switch sk {
            case .delete:
                proxy.deleteBackward()
            case .forwardDelete:
                proxy.adjustTextPosition(byCharacterOffset: 1)
                proxy.deleteBackward()
            case .return:
                proxy.insertText("\n")
            case .tab:
                proxy.insertText("\t")
            case .escape:
                break
            case .arrowLeft:
                proxy.adjustTextPosition(byCharacterOffset: -1)
            case .arrowRight:
                proxy.adjustTextPosition(byCharacterOffset: 1)
            case .arrowUp, .arrowDown:
                break   // UITextDocumentProxy has no line-level movement
            }
        }
    }
}

// MARK: - BLEKeyboardReceiverDelegate

extension KeyboardViewController: BLEKeyboardReceiverDelegate {

    func bleReceiver(_ receiver: BLEKeyboardReceiver, didReceive event: KeystrokeEvent) {
        DispatchQueue.main.async { self.apply(event) }
    }

    func bleReceiverDidConnect(_ receiver: BLEKeyboardReceiver) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Connected — type on your Mac"
            self.statusLabel.textColor = .systemGreen
        }
    }

    func bleReceiverDidDisconnect(_ receiver: BLEKeyboardReceiver) {
        DispatchQueue.main.async {
            self.statusLabel.textColor = .secondaryLabel
        }
    }

    func bleReceiver(_ receiver: BLEKeyboardReceiver, didUpdateStatus status: String) {
        DispatchQueue.main.async { self.statusLabel.text = status }
    }
}
