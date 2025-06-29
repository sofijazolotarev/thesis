//
//  TabController.swift
//  usersApp
//
//  Created by Sofija Zolotarev on 6.5.25..
//

import UIKit

class TabController: UITabBarController{
    var bluetoothManager: BluetoothCore?
    var recordView: RecordView?
    var hasPresentedChooser = false
    private var startupAlertScheduled = false

    override func viewDidLoad() {
        super.viewDidLoad()

        if bluetoothManager == nil {
            bluetoothManager = BluetoothCore.shared
        }

        let hasPeripheral = bluetoothManager?.defaultPeripheral != nil || (bluetoothManager?.deviceName != nil)
        let isRecording = UserDefaults.standard.bool(forKey: "isRecording")

        if hasPeripheral {
            self.selectedIndex = isRecording ? 1 : 0
            print(isRecording ? "opening markers screen" : "opening the recording screen")
        } else {
            self.selectedIndex = 2
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let manager = bluetoothManager else { return }

        manager.refreshDefaultPeripheralIfNeeded()
        
        if !startupAlertScheduled,
           manager.deviceName != nil,
           (manager.isConnected ?? 0) != 1 {
            startupAlertScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self, let mgr = self.bluetoothManager else { return }
                if (mgr.isConnected ?? 0) != 1 {
                    self.showStartupAlert(deviceName: mgr.deviceName ?? "your device")
                }
            }
        }

        if !hasPresentedChooser && manager.defaultPeripheral == nil {
            if manager.deviceName == nil {
                hasPresentedChooser = true
                performSegue(withIdentifier: "chooseDefaultDevice", sender: nil)
                print("opening the forget device screen")
                print("opening the forget device screen")
            }
        }
    }

    private func showStartupAlert(deviceName: String) {
        if presentedViewController is UIAlertController { return }
        let alert = UIAlertController(title: "Device not connected", message: "Make sure \(deviceName) is turned on and within range in order to continue.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
