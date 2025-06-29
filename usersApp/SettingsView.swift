//
//  SettingsView.swift
//  usersApp
//
//  Created by Sofija Zolotarev on 30.4.25..
//

//uncomment loose electrode thing when ready

import UIKit

class SettingsView: UIViewController {
    var bluetoothManager: BluetoothCore!
    
    @IBOutlet weak var defaultPeripheralLabel: UILabel!
    @IBOutlet weak var websiteLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var markersLabel: UILabel!
    @IBOutlet weak var PP_IDLabel: UILabel!
    @IBOutlet weak var Study_IDLabel: UILabel!
    @IBOutlet weak var Session_IDLabel: UILabel!
    @IBOutlet weak var batteryLevelLabel: UILabel!
    @IBOutlet weak var storageLevelLabel: UILabel!
    
    @IBOutlet weak var submitFeedbackbutton: UIButton!
    @IBOutlet weak var forgetButton: UIButton!
    private var isDeviceOn = true
    private var customMarkers: [String] = []
    
    private let websiteURLString = "https://vu-ams.nl/contact/"
    private let supportEmail = "support@vu-ams.nl"
    
    private var isRecording: Bool { UserDefaults.standard.bool(forKey: "isRecording") }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        if bluetoothManager == nil {
            bluetoothManager = BluetoothCore.shared
        }
        
        styleButtonAsOutlined(forgetButton)
        styleButtonAsOutlined(submitFeedbackbutton)
        
        updateLabels()
        
        setupBluetoothCallbacks()
        loadMarkers()
        
        configureLinkLabels()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMarkerListUpdated),
                                               name: .markerListUpdated,
                                               object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupBluetoothCallbacks()
        updateLabels()
    }
    
    private func setupBluetoothCallbacks() {
            bluetoothManager.onConnectionUpdate = { [weak self] _ in
                DispatchQueue.main.async {
                    print("on conection callbacl")
                    self?.updateLabels()
                }
            }

            bluetoothManager.onPPIDUpdate = { [weak self] PP_ID in
                DispatchQueue.main.async {
                    self?.updateLabels()
                }
            }

            bluetoothManager.onDeviceNameUpdate = { [weak self] name in
                DispatchQueue.main.async {
                    self?.defaultPeripheralLabel.text = name
                    self?.updateLabels()
                }
            }

            bluetoothManager.onSessionUpdate = { [weak self] sessionNr in
                DispatchQueue.main.async {
                    self?.Session_IDLabel.text = "Session: \(sessionNr)"
                    self?.updateLabels()
                }
            }

            bluetoothManager.onStudyIDUpdate = { [weak self] study_ID in
                DispatchQueue.main.async {
                    self?.Study_IDLabel.text = "Student_ID: \(study_ID)"
                    self?.updateLabels()
                }
            }

            bluetoothManager.onBatteryLevelUpdate = { [weak self] batteryLevel in
                DispatchQueue.main.async {
                    self?.batteryLevelLabel.text = "Battery: \(batteryLevel)%"
                    self?.updateLabels()
                }
            }

            bluetoothManager.onStorageUpdate = { [weak self] free, total in
                DispatchQueue.main.async {
                    let freeGB = Double(free) / 1024.0
                    let totalGB = Double(total) / 1024.0
                    self?.storageLevelLabel.text = String(format: "Storage: %.1f/%.1f GB", freeGB, totalGB)
                    self?.updateLabels()
                }
            }

            bluetoothManager.onLooseElectrodeDetected = { [weak self] in
                if UIApplication.shared.applicationState == .active {
                    DispatchQueue.main.async {
                        if let settingsView = self {

                        }
                    }
                }
            }
        }
        
        private func updateLabels() {
            print("on conection update label func")

            if bluetoothManager.isConnected == 1 {
                print("on conection if statement yes")

                defaultPeripheralLabel.text = bluetoothManager.deviceName
                Session_IDLabel.text = "Session: \(bluetoothManager.sessionNumber ?? "")"
                Study_IDLabel.text = "Student_ID: \(bluetoothManager.StudyID ?? "")"
                batteryLevelLabel.text = "Battery: \(bluetoothManager.lastKnownBatteryLevel ?? 0)%"
                PP_IDLabel.text = "PP_ID: \(bluetoothManager.PPID ?? "Not Available")"
                if let free = bluetoothManager.diskFree, let total = bluetoothManager.diskSize {
                    let freeGB = Double(free) / 1024.0
                    let totalGB = Double(total) / 1024.0
                    storageLevelLabel.text = String(format: "Storage: %.1f/%.1f GB", freeGB, totalGB)
                } else if let memoryString = bluetoothManager.memoryString {
                    storageLevelLabel.text = "Storage: \(memoryString)"
                } else {
                    storageLevelLabel.text = "Storage: Not Available"
                }
            } else {
                defaultPeripheralLabel.text = "Choose device:"
                Session_IDLabel.text = ""
                Study_IDLabel.text = ""
                batteryLevelLabel.text = ""
                storageLevelLabel.text = ""
                PP_IDLabel.text = """
                You are currently not connected to a device. Make sure your device is turned on and within reach. If you still have problems you can try clicking on the button above and picking a new default device or contacting our support team below.
                """
            }
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
                self.saveMarkers()
            }
        })
        present(alert, animated: true)
    }
    
    private func loadMarkers() {
        customMarkers = UserDefaults.standard.stringArray(forKey: "customMarkers") ?? []
        updateMarkersLabel()
    }
    
    private func saveMarkers() {
        UserDefaults.standard.set(customMarkers, forKey: "customMarkers")
        NotificationCenter.default.post(name: .markerListUpdated, object: nil)
    }
    
    @IBAction func forgetButtonPressed(_ sender: UIButton) {
        print("button clicked")
        bluetoothManager.disconnect()
        performSegue(withIdentifier: "chooseDefaultDevice", sender: nil)
    }
    
    @IBAction func addMarkerButtonPressed(_ sender: UIButton) {
        presentAddMarkerAlert()
    }
    
    @IBAction func deleteMarkerButtonPressed(_ sender: UIButton) {
        loadMarkers()
        if customMarkers.isEmpty{
            let alert = UIAlertController(title: "No markers to delete", message: "You have no markers defined.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Add Marker", style: .default, handler: { [weak self] _ in
                self?.presentAddMarkerAlert()
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }else{
            let alert = UIAlertController(title: "Delete Marker", message: "Select marker to delete", preferredStyle: .actionSheet)
            for marker in customMarkers {
                alert.addAction(UIAlertAction(title: marker, style: .destructive, handler: { [weak self] _ in
                    guard let self = self else { return }
                    if let index = self.customMarkers.firstIndex(of: marker) {
                        self.customMarkers.remove(at: index)
                        self.saveMarkers()
                    }
                }))
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }
    
    @IBAction func editButtonPressed(_ sender: UIButton) {
        loadMarkers()
        if customMarkers.isEmpty{
            let alert = UIAlertController(title: "No markers to edit", message: "You have no markers defined.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Add Marker", style: .default, handler: { [weak self] _ in
                self?.presentAddMarkerAlert()
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }else{
            let chooser = UIAlertController(title: "Edit Marker", message: "Select marker to edit", preferredStyle: .actionSheet)
            for marker in customMarkers {
                chooser.addAction(UIAlertAction(title: marker, style: .default, handler: { [weak self] _ in
                    self?.presentRenameAlert(for: marker)
                }))
            }
            chooser.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(chooser, animated: true)
        }
    }
    
    //??????????????
    private func presentRenameAlert(for oldMarker: String) {
        let rename = UIAlertController(title: "Rename Marker", message: nil, preferredStyle: .alert)
        rename.addTextField { tf in
            tf.text = oldMarker
            tf.placeholder = oldMarker
        }
        rename.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        rename.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            guard let newText = rename.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !newText.isEmpty else { return }
            if let idx = self.customMarkers.firstIndex(of: oldMarker) {
                self.customMarkers[idx] = newText
                self.saveMarkers()
            }
        }))
        present(rename, animated: true)
    }
    
    private func updateMarkersLabel() {
        if customMarkers.isEmpty {
            markersLabel.text = "No markers defined"
        } else {
            markersLabel.text = customMarkers.joined(separator: ", ")
        }
    }
    
    @objc private func handleMarkerListUpdated() {
        loadMarkers()
    }
    
    private func configureLinkLabels() {
        websiteLabel.isUserInteractionEnabled = true
        emailLabel.isUserInteractionEnabled = true
        
        let websiteTap = UITapGestureRecognizer(target: self, action: #selector(websiteTapped))
        websiteLabel.addGestureRecognizer(websiteTap)
        
        let emailTap = UITapGestureRecognizer(target: self, action: #selector(emailTapped))
        emailLabel.addGestureRecognizer(emailTap)
        
        let websiteAttr = NSAttributedString(string: websiteURLString, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        websiteLabel.attributedText = websiteAttr
        let emailAttr = NSAttributedString(string: supportEmail, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        emailLabel.attributedText = emailAttr
    }
    
    @objc private func websiteTapped() {
        guard let url = URL(string: "https://vu-ams.nl/contact/") else { return }
        UIApplication.shared.open(url)
    }
    
    @objc private func emailTapped() {
        let mailto = "mailto:support@vu-ams.nl"
        if let url = URL(string: mailto) {
            UIApplication.shared.open(url)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func styleButtonAsOutlined(_ button: UIButton, hexColor: String = "#1c676a", borderWidth: CGFloat = 1, cornerRadius: CGFloat = 14) {
        let borderColor = UIColor(hex: hexColor)
        button.backgroundColor = .clear
        button.layer.borderColor = borderColor.cgColor
        button.layer.borderWidth = borderWidth
        button.layer.cornerRadius = cornerRadius
        button.setTitleColor(borderColor, for: .normal)
        button.clipsToBounds = true
    }
}
