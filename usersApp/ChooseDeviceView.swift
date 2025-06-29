//
//  ChooseDeviceView.swift
//  usersApp
//
//  Created by Sofija Zolotarev on 30.4.25..
//

import Foundation
import UIKit
import CoreBluetooth

class ChooseDeviceView: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var bluetoothManager: BluetoothCore!
    var isFirstTime = true
    var selectedPeripheral: CBPeripheral?
    var onDeviceSelected: ((CBPeripheral) -> Void)?
    
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        print("viewDidLoad of chooseDevice view")

        super.viewDidLoad()
        setupTableView()
        bluetoothManager = BluetoothCore.shared
        
        bluetoothManager.onPeripheralListUpdate = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.tableView.reloadData()
        }
        
        print("end of viewdid load")

        //I dont think this should be here
        bluetoothManager.startScanning()
    }
    
    func setupTableView() {
        print("setup table ")

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PeripheralCell")
        
        title = "Select a Device"

        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("tableView:numberOfRowsInSection - Peripherals count: \(bluetoothManager.discoveredPeripherals.count)")
        return bluetoothManager.discoveredPeripherals.count
    }

    // In cellForRowAt
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return AddACell(cellForRowAt: indexPath)
    }
    
    func AddACell(cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("add a cell ")
        let cell = tableView.dequeueReusableCell(withIdentifier: "PeripheralCell", for: indexPath)
        let peripheral = bluetoothManager.discoveredPeripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name ?? "Unnamed"
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        print("tableView did select row at ")
        let peripheral = bluetoothManager.discoveredPeripherals[indexPath.row]
        selectedPeripheral = peripheral
        
        bluetoothManager.defaultPeripheral = peripheral
        
        bluetoothManager.connect(to: peripheral)
        
        onDeviceSelected?(peripheral) //check this
        
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark //check this
    }
    
    
    
    @IBAction func confirmButtonPressed(_ sender: UIButton) {
        print("confirm button pressed")
        if selectedPeripheral == nil {
            let alert = UIAlertController(
                title: "No Device Selected", 
                message: "Please select a device to continue.", 
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        if let p = selectedPeripheral {
            BluetoothCore.shared.defaults.set(p.identifier.uuidString, forKey: "defaultPeripheralUUID")
            BluetoothCore.shared.defaultPeripheral = p
        }
        
        dismiss(animated: true, completion: nil)
    }
}
