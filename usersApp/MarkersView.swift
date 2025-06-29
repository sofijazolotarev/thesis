//
//  MarkersView.swift
//  usersApp
//
//  Created by Sofija Zolotarev on 30.4.25..
//

import UIKit

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

class MarkerFlowLayout: UIView {
    private var buttons: [UIButton] = []
    private var deleteButtons: [UIButton] = []
    private var maxWidth: CGFloat = 0
    private let horizontalSpacing: CGFloat = 10
    private let verticalSpacing: CGFloat = 10
    
    var onButtonTapped: ((UIButton) -> Void)?
    var onDeleteButtonTapped: ((UIButton, UIButton) -> Void)?
    var onContentHeightChanged: ((CGFloat) -> Void)?
    
    init(frame: CGRect, maxWidth: CGFloat) {
        self.maxWidth = maxWidth
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func addButton(_ button: UIButton) {
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        buttons.append(button)
        addSubview(button)
        
        if button.currentTitle != nil {
            let deleteButton = createDeleteButton(for: button)
            deleteButtons.append(deleteButton)
            addSubview(deleteButton)
            deleteButton.isHidden = true
        }
        
        setNeedsLayout()
    }
    
    private func createDeleteButton(for markerButton: UIButton) -> UIButton {
        let deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "x.circle"), for: .normal)
        deleteButton.tintColor = markerButton.titleColor(for: .normal)
        deleteButton.backgroundColor = UIColor(hex: "#ebf9fa")
        deleteButton.layer.cornerRadius = 10
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.tag = buttons.count - 1
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped(_:)), for: .touchUpInside)
        return deleteButton
    }
    
    func removeAllButtons() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        
        deleteButtons.forEach { $0.removeFromSuperview() }
        deleteButtons.removeAll()
    }
    
    @objc private func buttonTapped(_ sender: UIButton) {
        onButtonTapped?(sender)
    }
    
    @objc private func deleteButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        if index < buttons.count {
            let markerButton = buttons[index]
            onDeleteButtonTapped?(markerButton, sender)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !buttons.isEmpty else { return }
        
        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0
        let buttonHeight: CGFloat = 60
        var rowHeight: CGFloat = buttonHeight
        
        for button in buttons {
            let buttonTitle = button.title(for: .normal) ?? ""
            let titleWidth = CGFloat(buttonTitle.count) * 10.0 + 40.0
            let buttonWidth = min(max(titleWidth, 120.0), maxWidth)
            
            if xOffset + buttonWidth > maxWidth {
                xOffset = 0
                yOffset += rowHeight + verticalSpacing
            }
            
              button.frame = CGRect(x: xOffset, y: yOffset, width: buttonWidth, height: buttonHeight)
              

            if button.currentTitle != nil {
                let buttonIndex = buttons.firstIndex(of: button) ?? 0
                if buttonIndex < deleteButtons.count {
                    let deleteButton = deleteButtons[buttonIndex]
                    let deleteButtonSize: CGFloat = 20
                    deleteButton.frame = CGRect(
                        x: xOffset + buttonWidth - deleteButtonSize/2,
                        y: yOffset - deleteButtonSize/2,
                        width: deleteButtonSize,
                        height: deleteButtonSize
                    )
                }
            }
            
            xOffset += buttonWidth + horizontalSpacing
        }
        
        let totalHeight = yOffset + rowHeight
        onContentHeightChanged?(totalHeight)
    }
    

    func setMarkerButtonsDimmed(_ dimmed: Bool) {
        for btn in buttons {
            if btn.currentTitle != nil {
                btn.alpha = dimmed ? 0.3 : 1.0
            }
        }
    }
    
    func setEditMode(_ enabled: Bool) {
        for (index, button) in buttons.enumerated() {
            if button.currentTitle != nil {
                if index < deleteButtons.count {
                    deleteButtons[index].isHidden = !enabled
                }
                
                if enabled {
                    applyDancingAnimation(to: button)
                } else {
                    button.layer.removeAllAnimations()
                }
            }
        }
    }
    
    private func applyDancingAnimation(to button: UIButton) {
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation")
        animation.values = [-0.025, 0.025, -0.025]
        animation.duration = 0.2
        animation.repeatCount = Float.infinity
        button.layer.add(animation, forKey: "wiggleAnimation")
    }
}

class MarkersView: UIViewController {
    var bluetoothManager: BluetoothCore!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var markersLabel: UILabel!
    private var isInEditMode = false
    private var markersFlowLayout: MarkerFlowLayout!
    private var customMarkers: [String] = []
    private var markerColors: [String: String] = [:]
    private var markersFlowLayoutHeightConstraint: NSLayoutConstraint?
    private let colorPool: [String] = [
        "#22b5c7",  // Turquoise blue
        "#8bba69",  // Green
        "#f29e51",  // Orange
        "#b6bc75",  // Olive green
        "#dd80c6"   // Pink
    ]
    
    private var isDeviceReady: Bool {
        return bluetoothManager.isConnected == 1 && bluetoothManager.isRecording == 1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        editButton.setTitle("Edit", for: .normal)
        
        print("Initial battery value: \(bluetoothManager?.lastKnownBatteryLevel ?? -1)")
        
        if bluetoothManager == nil {
            bluetoothManager = BluetoothCore.shared
        }
        
        setupMarkersStack()
        loadMarkers()
        rebuildMarkerButtons()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMarkerListUpdate),
                                               name: .markerListUpdated,
                                               object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupBluetoothCallbacks()
        rebuildMarkerButtons()
        updateMarkerButtonState()
    }
    
    private func setupBluetoothCallbacks() {
        bluetoothManager.onConnectionUpdate = { [weak self] _ in
            DispatchQueue.main.async { self?.updateMarkerButtonState() }
        }
        bluetoothManager.onRecordingUpdate = { [weak self] _ in
            DispatchQueue.main.async { self?.updateMarkerButtonState() }
        }
    }

    private func setupMarkersStack() {
        let screenWidth = UIScreen.main.bounds.width
        let availableWidth = screenWidth - 40 // 20pt padding on each side
        
        let initialFrame = CGRect(x: 0, y: 0, width: availableWidth, height: 100)
        markersFlowLayout = MarkerFlowLayout(frame: initialFrame, maxWidth: availableWidth)
        markersFlowLayout.translatesAutoresizingMaskIntoConstraints = false
        
        markersFlowLayout.onButtonTapped = { [weak self] button in
            guard let self = self else { return }
            
            if self.isInEditMode && button.currentTitle != nil {
                self.presentRenameMarkerAlert(for: button)
                return
            }
            
            print("button tapped")
            
            if let title = button.currentTitle {
                if self.isDeviceReady {
                    self.bluetoothManager.sendMarker(title)
                    setAlert("Marker sent...")
                }else {
                    self.present(self.deviceNotReadyAlert(), animated: true)
                    setAlert("Failed to send a marker.")
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.setAlert("")
                }
            } else {
                self.addMarkerTapped()
            }
        }
        
        markersFlowLayout.onDeleteButtonTapped = { [weak self] markerButton, deleteButton in
            guard let self = self, let title = markerButton.currentTitle else { return }
            self.deleteMarker(title: title)
        }
        
        markersFlowLayoutHeightConstraint = markersFlowLayout.heightAnchor.constraint(equalToConstant: 100)
        
        view.addSubview(markersFlowLayout)
        
        NSLayoutConstraint.activate([
            markersFlowLayout.topAnchor.constraint(equalTo: editButton.bottomAnchor, constant: 24),
            markersFlowLayout.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            markersFlowLayout.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            markersFlowLayoutHeightConstraint!
        ])
        
        markersFlowLayout.onContentHeightChanged = { [weak self] height in
            guard let self = self else { return }
            self.markersFlowLayoutHeightConstraint?.constant = max(height, 1)
        }
        
        updateMarkerButtonState()
    }
    
    private func loadMarkers() {
        customMarkers = UserDefaults.standard.stringArray(forKey: "customMarkers") ?? []
        if let savedColors = UserDefaults.standard.dictionary(forKey: "markerColors") as? [String: String] {
            markerColors = savedColors
        }
    }
    
    private func saveMarkers() {
        UserDefaults.standard.set(customMarkers, forKey: "customMarkers")
        UserDefaults.standard.set(markerColors, forKey: "markerColors")
        
        NotificationCenter.default.post(name: .markerListUpdated, object: nil)
    }
    
    @objc private func handleMarkerListUpdate() {
        loadMarkers()
        rebuildMarkerButtons()
    }
    
    private func rebuildMarkerButtons() {
        markersFlowLayout.removeAllButtons()
        
        var lastColorHex: String? = nil
        
        for title in customMarkers {
            let btn = UIButton(type: .system)
            
            let colorHex: String
            if let savedColorHex = markerColors[title] {
                colorHex = savedColorHex
            } else {
                let colorIndex = customMarkers.firstIndex(of: title)?.hashValue ?? 0
                colorHex = colorPool[abs(colorIndex) % colorPool.count]
                markerColors[title] = colorHex
            }
            
            let borderColor = UIColor(hex: "#1c676a")

            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
            btn.layer.cornerRadius = 14
            btn.layer.borderColor = UIColor(hex: colorHex).cgColor
            btn.backgroundColor = .clear
            btn.layer.borderWidth = 1
            btn.setTitleColor(UIColor(hex: colorHex), for: .normal)
            btn.clipsToBounds = true

            
            
            markersFlowLayout.addButton(btn)
        }
        
        let addBtn = UIButton(type: .system)
        addBtn.setImage(UIImage(systemName: "plus"), for: .normal)
        addBtn.tintColor = UIColor(hex: "22b5c7#")
        addBtn.backgroundColor = .clear
        addBtn.layer.cornerRadius = 14
        addBtn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        addBtn.addTarget(self, action: #selector(addMarkerTapped), for: .touchUpInside)
        addBtn.layer.borderColor = UIColor(hex: "#22b5c7") .cgColor
        addBtn.layer.borderWidth = 1
        addBtn.setTitleColor(UIColor(hex: "22b5c7#"), for: .normal)
        addBtn.clipsToBounds = true
        markersFlowLayout.addButton(addBtn)
        
        updateMarkerButtonState()
    }
    
    private func saveColorMappings() {
        UserDefaults.standard.set(markerColors, forKey: "markerColors")
    }
        
    @objc private func addMarkerTapped() {
        presentAddMarkerAlert()
    }
    
    private func presentAddMarkerAlert() {
        let alert = UIAlertController(title: "New Marker", message: "Enter marker text", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Marker text" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self,
                  let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }
            
            if !self.customMarkers.contains(text) {
                self.customMarkers.append(text)
                
                if self.markerColors[text] == nil {
                    let colorIndex = abs(text.hashValue) % self.colorPool.count
                    self.markerColors[text] = self.colorPool[colorIndex]
                }
                
                self.saveMarkers()
                self.rebuildMarkerButtons()
            }
        })
        present(alert, animated: true)
    }
    
    private func updateMarkerButtonState() {
        if isInEditMode {
            markersFlowLayout.setMarkerButtonsDimmed(false)
        } else {
            let ready = isDeviceReady
            markersFlowLayout.setMarkerButtonsDimmed(!ready)
        }
    }
    
    private func deviceNotReadyAlert() -> UIAlertController {
        let alert = UIAlertController(
            title: "Cannot Send Marker",
            message: "You must be connected to a device and actively recording to send markers.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        return alert
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func editButtonPressed(_ sender: UIButton) {
        isInEditMode = !isInEditMode
        editButton.setTitle(isInEditMode ? "Done" : "Edit", for: .normal)
        markersFlowLayout.setEditMode(isInEditMode)
        updateMarkerButtonState()
    }
    
    private func deleteMarker(title: String) {
        if let index = customMarkers.firstIndex(of: title) {
            customMarkers.remove(at: index)
            markerColors.removeValue(forKey: title)
            
            saveMarkers()
            rebuildMarkerButtons()
            
            markersFlowLayout.setEditMode(isInEditMode)
        }
    }
    
    private func presentRenameMarkerAlert(for button: UIButton) {
        guard let currentTitle = button.currentTitle else { return }
        
        let alert = UIAlertController(title: "Rename Marker", message: "Enter new marker name", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Marker name"
            textField.text = currentTitle
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
            guard let self = self,
                  let newTitle = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newTitle.isEmpty,
                  newTitle != currentTitle else { return }
            
            if self.customMarkers.contains(newTitle) {
                self.showErrorAlert(message: "A marker with this name already exists.")
                return
            }
            
            if let index = self.customMarkers.firstIndex(of: currentTitle) {
                let colorHex = self.markerColors[currentTitle] ?? self.colorPool[0]
                
                self.customMarkers[index] = newTitle
                self.markerColors.removeValue(forKey: currentTitle)
                self.markerColors[newTitle] = colorHex
                
                self.saveMarkers()
                self.rebuildMarkerButtons()
                
                self.markersFlowLayout.setEditMode(self.isInEditMode)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func setAlert(_ message: String,
                  emphasisColor: UIColor = UIColor(hex: "#35b0ad"),
                  pulseScale: CGFloat = 1) {

        markersLabel.layer.removeAllAnimations()

        UIView.animate(withDuration: 0.2, animations: {
            self.markersLabel.alpha = 0
        }) { _ in
            self.markersLabel.text = message
            self.markersLabel.textColor = emphasisColor
            self.markersLabel.transform = .identity
            self.markersLabel.alpha = 0        

            UIView.animate(withDuration: 0.3, animations: {
                self.markersLabel.alpha = 1
                self.markersLabel.transform = CGAffineTransform(scaleX: pulseScale,
                                                              y: pulseScale)
            }) { _ in
                UIView.animate(withDuration: 0.12, animations: {
                    self.markersLabel.transform = .identity
                }) { _ in
                    UIView.animate(withDuration: 0.1) {
                        self.markersLabel.textColor = UIColor(hex: "#1c676a")
                    }
                }
            }
        }
    }
}
