//
//  BluetoothCore.swift
//  usersApp
//
//  Created by Sofija Zolotarev on 30.4.25..
//

//notes:
//what is deadline used for? should we make all of it now?
//on PPIDUpdate, onSessionUpdate, onStudyIDUpdate, onDeviceNameUpdate could all just be onConnectionUpdate
//no need for looseElectrode alerts in the testing stage

import CoreBluetooth
import Foundation
import UserNotifications

final class BluetoothCore: NSObject {
    static let shared = BluetoothCore()
    
    static let looseElectrodeNotificationCategoryID = "LOOSE_ELECTRODE_ALERT"
    var helper = 0
    
    var onDeviceNameUpdate: ((String) -> Void)?
    var onBatteryLevelUpdate: ((Int) -> Void)?
    var onStorageUpdate: ((Int, Int) -> Void)?
    var onSessionUpdate: ((String) -> Void)?
    var onPeripheralListUpdate: (() -> Void)?
    var onStudyIDUpdate: ((String) -> Void)?
    var onPPIDUpdate: ((String) -> Void)?
    var onLooseElectrodeDetected: (() -> Void)?
    var onConnectionUpdate: ((Bool) -> Void)?
    var onRecordingUpdate: ((Bool) -> Void)?

    private(set) var deviceName: String?
    private(set) var lastKnownBatteryLevel: Int?
    private(set) var diskFree: Int?
    private(set) var diskSize: Int?
    private(set) var memoryString: String?
    private(set) var StudyID: String?
    private(set) var sessionNumber: String?
    private(set) var PPID: String?
    private(set) var LooseElectrodeDetection: String?
    private(set) var isConnected: Int?
    private(set) var isRecording: Int? {
        get { UserDefaults.standard.integer(forKey: "isRecording") }
        set { UserDefaults.standard.set(newValue, forKey: "isRecording") }
    }
    
    private var commandCharacteristic: CBCharacteristic?
    private var commandQueue: [String] = []
    private var isExecutingCommand = false
    
    let defaults = UserDefaults.standard
    var connectedPeripheral: CBPeripheral?
    private(set) var discoveredPeripherals: [CBPeripheral] = []
    var defaultPeripheral: CBPeripheral? {
        didSet {
            NotificationCenter.default.post(name: .defaultPeripheralUpdated, object: defaultPeripheral)
            
            if let peri = defaultPeripheral {
                deviceName = peri.name
                if let name = peri.name {
                    onDeviceNameUpdate?(name)
                    defaults.set(name, forKey: "defaultPeripheralName")
                }
            }
        }
    }
    
    lazy var centralManager: CBCentralManager = {
        CBCentralManager(delegate: self, queue: .main)
    }()
    
    private override init() {
        super.init()
        
        setupNotificationCategories()
        
        if let uuidString = defaults.string(forKey: "defaultPeripheralUUID"),
           let uuid = UUID(uuidString: uuidString) {
            let found = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let p = found.first {
                defaultPeripheral = p
            }
        }
        
        if deviceName == nil, let savedName = defaults.string(forKey: "defaultPeripheralName") {
            deviceName = savedName
        }
        
        requestNotificationAuthorization()
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return}
        
        discoveredPeripherals.removeAll()
        
        centralManager.scanForPeripherals(
            withServices: [CBUID_deviceInfoService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func stopScanning() {
        centralManager.stopScan()
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        centralManager.connect(peripheral, options: nil)
        connectedPeripheral = peripheral
        defaults.set(peripheral.identifier.uuidString, forKey: "defaultPeripheralUUID")
    }

    func disconnect() {
        guard let p = connectedPeripheral else {return}
        centralManager.cancelPeripheralConnection(p)
    }

    func startRecording()  {
        guard isConnected != 0 else {return}

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.queueCommand("r")
            self.isRecording = 1
            self.onRecordingUpdate?(true)
        }
    }
    
    func stopRecording()   {
        guard isConnected != 0 else {return}

        queueCommand("s")
        isRecording = 0
        onRecordingUpdate?(false)
    }
     
    func turnDeviceOff() {
        guard isConnected != 0 else {return}
        
        queueCommand("Q")
    }
    
    func sendMarker(_ text: String) {
        guard isConnected != 0 else {return}

        let clean = text.replacingOccurrences(of: " ", with: "")
        let cmd = "!MARKER=\(clean);"
        print("marker cmd:", cmd)
        queueCommand(cmd)
    }
    
    func queueCommand(_ cmd: String) {
        commandQueue.append(cmd)
        print("inside queue command")
        processCommandQueue()
    }
    
    private func processCommandQueue() {
        print("inside processCommandQueue")

        guard !isExecutingCommand, !commandQueue.isEmpty else { return }

        guard let writeChar = commandCharacteristic else {
            connectedPeripheral?.discoverServices([AMS_WriteService])
            return
        }

        guard let cmd = commandQueue.first,
              let data = cmd.data(using: .utf8),
              let peripheral = connectedPeripheral else { return }

        print("passed all the checks")
        isExecutingCommand = true
        peripheral.writeValue(data, for: writeChar, type: .withResponse)

        if cmd == "Q"{
            commandQueue.removeAll()
        }else{
            commandQueue.removeFirst()
        }
    }

    func refreshDefaultPeripheralIfNeeded() {
        guard defaultPeripheral == nil else {
            print("guard faild")
        return}
        print("inside refreshDefaultPeripheralIfNeeded")
        if let uuidString = defaults.string(forKey: "defaultPeripheralUUID"),
           let uuid = UUID(uuidString: uuidString) {
            let retrieved = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let p = retrieved.first {
                defaultPeripheral = p // triggers notification
                print("Cached peripheral: \(defaultPeripheral)")
            }
        }
    }
}

extension BluetoothCore: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if defaultPeripheral == nil,
               let uuidString = defaults.string(forKey: "defaultPeripheralUUID"),
               let uuid = UUID(uuidString: uuidString) {
                let retrieved = centralManager.retrievePeripherals(withIdentifiers: [uuid])
                if let p = retrieved.first {
                    defaultPeripheral = p
                }
            }
            
            refreshDefaultPeripheralIfNeeded()
            
            startScanning()
            
            if let cached = defaultPeripheral, connectedPeripheral == nil {
                connect(to: cached)
            }
        case .poweredOff:  print("🔵 BLE State: POWERED OFF - Bluetooth is turned off")
        case .resetting:   print("🔵 BLE State: RESETTING")
        case .unauthorized: print("🔵 BLE State: UNAUTHORIZED - Missing permissions")
        case .unsupported: print("🔵 BLE State: UNSUPPORTED - Hardware doesn't support Bluetooth")
        case .unknown:     print("🔵 BLE State: UNKNOWN - Initializing")
        @unknown default:  print("🔵 BLE State: UNKNOWN DEFAULT STATE: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        guard let name = peripheral.name else { return }
        
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            onDeviceNameUpdate?(name)
            deviceName = peripheral.name
            onPeripheralListUpdate?()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = 1
        onConnectionUpdate?(true)
        defaultPeripheral = peripheral
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        if !commandQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
                self?.processCommandQueue()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = 0
        onConnectionUpdate?(false)
        if let cached = defaultPeripheral, peripheral.identifier == cached.identifier {
            DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
                self?.connect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = 0
        onConnectionUpdate?(false)
        if let index = discoveredPeripherals.firstIndex(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.remove(at: index)
            onPeripheralListUpdate?()
        }
        
        connectedPeripheral = nil
        commandCharacteristic = nil
    }
}

extension Notification.Name {
    static let defaultPeripheralUpdated = Notification.Name("defaultPeripheralUpdated")
    static let markerListUpdated       = Notification.Name("markerListUpdated")
}

extension BluetoothCore: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard error == nil else {return}
        guard let services = peripheral.services else { return }
        for service in services {
            switch service.uuid {
            case AMS_Service:
                peripheral.discoverCharacteristics([
                    CBUID_SessionNr,
                    CBUID_MemoryAvailableOnCard,
                    CBUID_PP_ID,
                    CBUID_StudyID,
                    CBUID_SessionNr,
                    CBUID_LooseElectrodeDetection,
                ], for: service)
            case AMS_WriteService: // command characteristic lives here
                peripheral.discoverCharacteristics([CBUID_sendCommand], for: service)
            case CBUID_batterySensorService:
                peripheral.discoverCharacteristics([CBUID_batteryLevel], for: service)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {return}
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case CBUID_batteryLevel, CBUID_SessionNr, CBUID_MemoryAvailableOnCard, CBUID_PP_ID, CBUID_StudyID, CBUID_LooseElectrodeDetection:
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            case CBUID_sendCommand:
                commandCharacteristic = characteristic
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                if !commandQueue.isEmpty {
                    processCommandQueue()
                }
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else {return}
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case CBUID_PP_ID:
            if let PP_ID = String(data: data, encoding: .utf8) {
                onPPIDUpdate?(PP_ID)
                PPID = PP_ID
            }
        case CBUID_StudyID:
            if let study_ID = String(data: data, encoding: .utf8) {
                onStudyIDUpdate?(study_ID)
                StudyID = study_ID
            }
        case CBUID_SessionNr:
            if let session = String(data: data, encoding: .utf8) {
                onSessionUpdate?(session)
                sessionNumber = session
            }
        case CBUID_LooseElectrodeDetection:
            if let looseStatus = String(data: data, encoding: .utf8) {
                LooseElectrodeDetection = looseStatus
                onLooseElectrodeDetected?()
 
                if helper == 0 {
                    sendLooseElectrodeNotification()
                    helper = 1
                }else{
                    helper = 0
                }
            }
        case CBUID_batteryLevel:
            let percent = Int(data.withUnsafeBytes { $0.load(as: UInt8.self) })
            let previousLevel = lastKnownBatteryLevel
            onBatteryLevelUpdate?(percent)
            lastKnownBatteryLevel = percent
            
            checkBatteryLevelAndNotify(percent: percent, previousLevel: previousLevel)
        case CBUID_MemoryAvailableOnCard:
            if let str = String(data: data, encoding: .utf8) {
                let indMB = str.ranges(of: "MB")
                let indOf = str.ranges(of: "(of")
                if indMB.count >= 2, indOf.count >= 1 {
                    let free = Int(str[str.startIndex..<indMB[0].lowerBound].filter("0123456789".contains)) ?? 0
                    let total = Int(str[indOf[0].upperBound..<indMB[1].lowerBound].filter("0123456789".contains)) ?? 0
                    onStorageUpdate?(free, total)
                    diskFree = free
                    diskSize = total
                    memoryString = str
                }
            }
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Failed to write value for \(characteristic.uuid): \(error.localizedDescription)")
        } else {
            print("Successfully wrote value for \(characteristic.uuid)")
        }
        // Mark current command as finished and continue with the next one.
        isExecutingCommand = false
        processCommandQueue()
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Failed to update notification state for \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        print("Notification state updated for \(characteristic.uuid) – isNotifying: \(characteristic.isNotifying)")
    }
}

extension BluetoothCore {
    static let batteryNotificationCategoryID = "BATTERY_ALERT"
    static let storageNotificationCategoryID = "STORAGE_ALERT"
    
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Failed to get notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    func setupNotificationCategories() {
        let checkAction = UNNotificationAction(identifier: "CHECK_ELECTRODE",
                                             title: "Check Electrode",
                                             options: .foreground)
        
        let checkBatteryAction = UNNotificationAction(identifier: "CHECK_BATTERY",
                                                  title: "Check Battery",
                                                  options: .foreground)
        
        let checkStorageAction = UNNotificationAction(identifier: "CHECK_STORAGE",
                                                   title: "Check Storage",
                                                   options: .foreground)
        
        let looseElectrodeCategory = UNNotificationCategory(
            identifier: BluetoothCore.looseElectrodeNotificationCategoryID,
            actions: [checkAction],
            intentIdentifiers: [],
            options: [.customDismissAction])
        
        let batteryCategory = UNNotificationCategory(
            identifier: BluetoothCore.batteryNotificationCategoryID,
            actions: [checkBatteryAction],
            intentIdentifiers: [],
            options: [.customDismissAction])
        
        let storageCategory = UNNotificationCategory(
            identifier: BluetoothCore.storageNotificationCategoryID,
            actions: [checkStorageAction],
            intentIdentifiers: [],
            options: [.customDismissAction])
        
        UNUserNotificationCenter.current().setNotificationCategories([looseElectrodeCategory, batteryCategory, storageCategory])
    }
    
    func sendLooseElectrodeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Loose Electrode Detected"
        content.body = "Your back electrode semmes to have moved."
        content.sound = .default
        content.categoryIdentifier = BluetoothCore.looseElectrodeNotificationCategoryID
        
        let identifier = "looseElectrode-\(Date().timeIntervalSince1970)"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            }
        }

    }
    
    func sendBatteryNotification(level: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Low Battery Alert"
        content.body = "Device battery is at \(level)%. Please charge soon."
        content.sound = .default
        content.categoryIdentifier = BluetoothCore.batteryNotificationCategoryID
        
        let identifier = "batteryAlert-\(level)-\(Date().timeIntervalSince1970)"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                //change the notification line
                print("Error sending battery notification: \(error.localizedDescription)")
            }
        }
    }
    
    func sendStorageNotification(percentRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Low Storage Alert"
        content.body = "Device storage is at \(percentRemaining)% remaining. Please free up space."
        content.sound = .default
        content.categoryIdentifier = BluetoothCore.storageNotificationCategoryID
        
        let identifier = "storageAlert-\(Date().timeIntervalSince1970)"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending storage notification: \(error.localizedDescription)")
            }
        }
    }
    
    func checkBatteryLevelAndNotify(percent: Int, previousLevel: Int?) {
        if let prev = previousLevel {
            if percent <= 5 && prev > 5 {
                sendBatteryNotification(level: 5)
            } else if percent <= 20 && prev > 20 && percent > 5 {
                sendBatteryNotification(level: 20)
            } else if percent <= 30 && prev > 30 && percent > 20 {
                sendBatteryNotification(level: 30)
            }
//            } else if percent <= 75 && prev > 75{
//                sendBatteryNotification(level: 75)
//            }
        } else {
            if percent <= 5 {
                sendBatteryNotification(level: 5)
            } else if percent <= 20 {
                sendBatteryNotification(level: 20)
            } else if percent <= 30 {
                sendBatteryNotification(level: 30)
            }
        }
    }
    
    func checkStorageSpaceAndNotify(free: Int, total: Int) {
        if total > 0 {
            let percentRemaining = (free * 100) / total
            if percentRemaining <= 10 {
                sendStorageNotification(percentRemaining: percentRemaining)
            }
        }
    }
}

extension UserDefaults {
    func saveMarker() {
        var markers = array(forKey: "markers") as? [Double] ?? []
        markers.append(Date().timeIntervalSince1970)
        set(markers, forKey: "markers")
    }
    
    func getMarkers() -> [Date] {
        let timestamps = array(forKey: "markers") as? [Double] ?? []
        return timestamps.map { Date(timeIntervalSince1970: $0) }
    }
}
