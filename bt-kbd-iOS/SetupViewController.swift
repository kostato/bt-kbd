import UIKit

class SetupViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "bt-kbd Setup"
        view.backgroundColor = .systemBackground
        buildUI()
    }

    private func buildUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])

        let icon = UIImageView(image: UIImage(systemName: "keyboard.fill"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 56).isActive = true
        stack.addArrangedSubview(icon)

        let title = UILabel()
        title.text = "bt-kbd – BLE Keyboard"
        title.font = .boldSystemFont(ofSize: 22)
        title.textAlignment = .center
        stack.addArrangedSubview(title)

        let steps = UILabel()
        steps.numberOfLines = 0
        steps.font = .systemFont(ofSize: 15)
        steps.textColor = .secondaryLabel
        steps.text = """
        1. Settings → General → Keyboard → Keyboards
        2. Add New Keyboard… → bt-kbd → Remote Keyboard
        3. Tap bt-kbd in the list → enable Full Access
        4. Open any app, tap a text field
        5. Hold 🌐 and select "Remote Keyboard"
        6. On your Mac, open bt-kbd and start typing
        """
        stack.addArrangedSubview(steps)

        let btn = UIButton(type: .system)
        btn.setTitle("Open Keyboard Settings", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17)
        btn.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        stack.addArrangedSubview(btn)
    }

    @objc private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
