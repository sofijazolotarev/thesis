//
//  RecordView.swift
//  usersApp
//
//  Created by Sofija Zolotarev on 30.4.25..
//

import CoreBluetooth
import Foundation
import UIKit
import SwiftData
import SwiftUI
import DotLottie

//@available(iOS 17, *)
class RecordView: UIViewController {
    var bluetoothManager: BluetoothCore!
    private var lottieAnimation: DotLottieAnimation?
    private var isLottieLoading = false
    private var lottieView: UIView?
    private let dotLottieURLString = "https://lottie.host/2c191d59-459d-4856-834e-7430bdc1461d/msH7AtrUFD.lottie"    
    private var deviceConnected: Bool {
        return bluetoothManager.isConnected == 1
    }
    private var hasDefaultPeripheral: Bool {
        return bluetoothManager.defaultPeripheral != nil
    }
    
    private var batteryPercent: Int? { didSet { checkBatteryLevel() } }
    private var freeStorageMB: Int? { didSet { checkStorageLevel() } }
    private var totalStorageMB: Int?
    
    private var hasShownLowBatteryAlert = false
    private var hasShownLowStorageAlert = false
    
    @IBOutlet weak var onOffButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var connectionButton: UIButton!
    @IBOutlet weak var storageStatusLabel: UILabel!
    @IBOutlet weak var batteryStatusLabel: UILabel!
    @IBOutlet weak var alertLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if bluetoothManager == nil {
            bluetoothManager = BluetoothCore.shared
        }
        
        styleButtonAsOutlined(onOffButton)
        styleButtonAsOutlined(connectionButton)
        
        setupBluetoothCallbacks()
        loadDotLottieIfNeeded()
        
        updateStatusLabels()
    }
    
    private func setupBluetoothCallbacks() {
        bluetoothManager.onBatteryLevelUpdate = { [weak self] batteryLevel in
            DispatchQueue.main.async {
                self?.batteryPercent = batteryLevel
                self?.updateStatusLabels()
            }
        }
        if let initialBattery = bluetoothManager.lastKnownBatteryLevel {
            batteryPercent = initialBattery
        }
        
        
        bluetoothManager.onStorageUpdate = { [weak self] free, total in
            DispatchQueue.main.async {
                self?.freeStorageMB  = free
                self?.totalStorageMB = total
                self?.updateStatusLabels()
            }
        }
        if let free = bluetoothManager.diskFree, let total = bluetoothManager.diskSize {
            freeStorageMB  = free
            totalStorageMB = total
        }
        
        bluetoothManager.onConnectionUpdate = { [weak self] connected in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if connected {
                    self.connectionButton.setTitle("disconnect", for: .normal)
                    self.setAlert("Connected to a device.")
                    self.onOffButton.alpha = 1
                    self.recordButton.alpha = 1
                    
                }else{
                    self.connectionButton.setTitle("connect", for: .normal)
                    self.setAlert("Not connected to a device.")
                    self.onOffButton.alpha = 0.3
                    self.recordButton.alpha = 0.3
                }
                self.updateStatusLabels()
            }
        }
        
        if deviceConnected {
            self.connectionButton.setTitle("disconnect", for: .normal)
            self.setAlert("Connected to a device.")
            self.onOffButton.alpha = 1
            self.recordButton.alpha = 1
        }else{
            self.connectionButton.setTitle("connect", for: .normal)
            self.setAlert("Not connected to a device.")
            self.onOffButton.alpha = 0.3
            self.recordButton.alpha = 0.3
        }
        
        bluetoothManager.onRecordingUpdate = { [weak self] recording in
            DispatchQueue.main.async {
                self?.updateRecordingUI(isRecording: recording)
            }
        }
        
        if let recording = bluetoothManager.isRecording {
            if recording == 1 {
                updateRecordingUI(isRecording: true)
            }else{
                updateRecordingUI(isRecording: false)
            }
        }
        
        bluetoothManager.onLooseElectrodeDetected = { [weak self] in
            if UIApplication.shared.applicationState == .active {
                DispatchQueue.main.async {
                    if let recordView = self {
                        // You can show a visual indicator in the UI instead of an alert
                    }
                }
            }
        }
    }
    
    private func updateRecordingUI(isRecording: Bool) {
        recordButton.subviews.filter { $0.tag == 100 }.forEach { $0.removeFromSuperview() }
        
        lottieView?.removeFromSuperview()
        lottieView = nil
        
        if isRecording {
            guard let lottieAnimReady = lottieAnimation else {
                loadDotLottieIfNeeded()
                return
            }
            
            if lottieAnimReady != nil {
                let lottieAnim = lottieAnimReady
                let dotLottieView = lottieAnim.view() as UIView
 
                let scaleFactor: CGFloat = 1.3
                let newSize = CGSize(width: recordButton.bounds.width * scaleFactor, height: recordButton.bounds.height * scaleFactor)
                let centerPoint = CGPoint(x: recordButton.bounds.width / 2, y: recordButton.bounds.height / 2)
                
                dotLottieView.frame = CGRect(
                    x: centerPoint.x - (newSize.width / 2),
                    y: centerPoint.y - (newSize.height / 2),
                    width: newSize.width,
                    height: newSize.height
                )
                
                if let lottieAnimView = dotLottieView as? UIView {
                    lottieAnimView.contentMode = .scaleAspectFill
                }
                
                dotLottieView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                dotLottieView.isUserInteractionEnabled = false
                
                recordButton.addSubview(dotLottieView)
                recordButton.bringSubviewToFront(dotLottieView)
                
                lottieView = dotLottieView
                
                recordButton.setImage(nil, for: .normal)
                recordButton.setTitle(nil, for: .normal)
                recordButton.titleLabel?.isHidden = true
                recordButton.imageView?.isHidden = true
                
                lottieAnim.play()
            }
        } else {
            recordButton.frame = recordButton.bounds
            recordButton.setImage(UIImage(named: "playButtonIcon"), for: .normal)
            recordButton.imageView?.isHidden = false
            recordButton.titleLabel?.isHidden = false
        }

    }
    
    @IBAction func recordPressed(_ sender: UIButton) {
        guard deviceConnected else {
            setAlert("Not connected to a device.")

            return
        }
        
        if bluetoothManager.isRecording == 1{
            bluetoothManager.stopRecording()
            updateRecordingUI(isRecording: false)
            setAlert("Not currently recording.")
        } else {
            bluetoothManager.startRecording()
            updateRecordingUI(isRecording: true)
            setAlert("Recording in process...")
        }
    }
    
    @IBAction func turnOffPressed(_ sender: UIButton) {
        bluetoothManager.turnDeviceOff()
        updateRecordingUI(isRecording: false)
        
        if bluetoothManager.isConnected == 1{
            setAlert("Turning the device off...")
        }else{
            setAlert("Not connected to a device.")
        }
    }
    
    @IBAction func disconnectPressed(_ sender: UIButton) {
        if deviceConnected {
            bluetoothManager.disconnect()
            sender.setTitle("connect", for: .normal)
            setAlert("Not connected to a device.")

        } else {
            if hasDefaultPeripheral, bluetoothManager.isConnected != nil {
                bluetoothManager.connect(to: bluetoothManager.defaultPeripheral!)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    
                    if self.deviceConnected {
                        sender.setTitle("disconnect", for: .normal)
                        self.setAlert("Connected to the device.")
                    } else {
                        self.showAlert(title: "Can't find your device", message: "Please make sure the device is turned on and within range.")
                        self.setAlert("Failed to connect to the device.")
                    }
                    
                    self.updateStatusLabels()
                }
            } else {
                showAlert(title: "No default device set", message: "If you want to add a default peripheral you can do so in the settings.")
            }
        }
        updateStatusLabels()
    }
    
    private func checkBatteryLevel() {
        guard let level = batteryPercent else { return }
        if level <= 10 && !hasShownLowBatteryAlert {
            hasShownLowBatteryAlert = true
            showAlert(title: "Low Battery", message: "Device battery is only \(level)% – please charge soon.")
        } else if level > 20 {
            hasShownLowBatteryAlert = false
        }
    }
    
    private func checkStorageLevel() {
        guard let free = freeStorageMB else { return }
        if free <= 100 && !hasShownLowStorageAlert {
            hasShownLowStorageAlert = true
            let freeGB = Double(free) / 1024.0
            showAlert(title: "Low Storage", message: String(format: "Only %.1f GB free remaining.", freeGB))
        } else if free > 200 {
            hasShownLowStorageAlert = false
        }
    }
    
    private func showAlert(title: String, message: String) {
        if presentedViewController is UIAlertController { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func loadDotLottieIfNeeded() {
        if lottieAnimation != nil || isLottieLoading { return }

        guard let url = URL(string: dotLottieURLString) else { return }
        isLottieLoading = true
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            defer { self.isLottieLoading = false }
            var finalData: Data? = data
            var status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if let http = response as? HTTPURLResponse {
                print("[DotLottie] HTTP status", http.statusCode, "length", data?.count ?? -1)
                if http.statusCode == 304 {
                    if let cached = URLCache.shared.cachedResponse(for: request) {
                        finalData = cached.data
                        status = 200
                        print("[DotLottie] using cached data (length", finalData?.count ?? -1, ")")
                    }
                }
                if http.statusCode == 403 && error == nil {
                    var altReq = request
                    altReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    URLSession.shared.dataTask(with: altReq) { data403, resp403, err403 in
                        let status403 = (resp403 as? HTTPURLResponse)?.statusCode ?? -1
                        if status403 == 200, let okData = data403 {
                            DispatchQueue.main.async {
                                self.finishLottieLoad(data: okData)
                            }
                        } else {
                            DispatchQueue.main.async {
                                print("[DotLottie] retry failed – status", status403)
                            }
                        }
                    }.resume()
                    return
                }
            }
            
            if let finalData = finalData, status == 200 {
                DispatchQueue.main.async {
                    self.lottieAnimation = DotLottieAnimation(dotLottieData: finalData,
                                                              config: AnimationConfig(autoplay: true, loop: true))
                    if self.bluetoothManager?.isRecording == 1 {
                        self.updateRecordingUI(isRecording: true)
                    }
                }
            } else {
                print("[DotLottie] download failed – status", status, "error", error?.localizedDescription ?? "nil")
            }
        }.resume()
    }
    
    private func finishLottieLoad(data: Data) {
        self.lottieAnimation = DotLottieAnimation(dotLottieData: data,
                                                  config: AnimationConfig(autoplay: true, loop: true))
        if bluetoothManager?.isRecording == 1 {
            updateRecordingUI(isRecording: true)
        }
    }
    
    func styleButtonAsOutlined(_ button: UIButton, hexColor: String = "#1c676a", borderWidth: CGFloat = 1, cornerRadius: CGFloat = 16) {
        let borderColor = UIColor(hex: hexColor)
        button.backgroundColor = .clear
        button.layer.borderColor = borderColor.cgColor
        button.layer.borderWidth = borderWidth
        button.layer.cornerRadius = cornerRadius
        button.setTitleColor(borderColor, for: .normal)
        button.clipsToBounds = true
    }
    
    
    private func styleStatusLabel(_ label: UILabel, hexColor: String = "#1c676a") {
        let borderColor = UIColor(hex: hexColor)
        
        label.backgroundColor = .none
        label.textColor = borderColor
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        label.layer.borderColor = borderColor.cgColor
        label.layer.borderWidth = 1
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
    }
    
    private func updateStatusLabels() {
        if let batteryLevel = batteryPercent, let free = freeStorageMB, let total = totalStorageMB, deviceConnected {
            batteryStatusLabel.isHidden  = false
            storageStatusLabel.isHidden  = false
            
            print("total:", total, "free:", free)
            
            batteryStatusLabel.text = "battery: \(batteryLevel)%"
            let storagePercent = Int((Double(free) * 100)/Double(total))
            storageStatusLabel.text = "storage: \(storagePercent)%"
            
            styleStatusLabel(batteryStatusLabel)
            styleStatusLabel(storageStatusLabel)
        }else{
            batteryStatusLabel.isHidden  = true
            storageStatusLabel.isHidden  = true
        }

    }
    
    func setAlert(_ message: String,
                  emphasisColor: UIColor = UIColor(hex: "#35b0ad"),
                  pulseScale: CGFloat = 1) {

        alertLabel.layer.removeAllAnimations()

        UIView.animate(withDuration: 0.2, animations: {
            self.alertLabel.alpha = 0
        }) { _ in
            self.alertLabel.text = message
            self.alertLabel.textColor = emphasisColor
            self.alertLabel.transform = .identity
            self.alertLabel.alpha = 0

            UIView.animate(withDuration: 0.3, animations: {
                self.alertLabel.alpha = 1
                self.alertLabel.transform = CGAffineTransform(scaleX: pulseScale,
                                                              y: pulseScale)
            }) { _ in
                UIView.animate(withDuration: 0.12, animations: {
                    self.alertLabel.transform = .identity
                }) { _ in
                    UIView.animate(withDuration: 0.1) {
                        self.alertLabel.textColor = UIColor(hex: "#1c676a")
                    }
                }
            }
        }
    }
}
