//
//  AppInfo.swift
//  usersApp
//
//  Created by Sofija Zolotarev on 30.4.25..
//

import Foundation
import SwiftData
import CoreBluetooth
@Model
class AppInfo
{
    /// The UUID string of the last connected peripheral that should be used for reconnection
    var defaultPeripheralId: String? = nil
    
    /// List of markers created during recording sessions
    var markersList: [String] = []
    
    /// Default initializer
    init() {
        print("[AppInfo] Init: Creating new AppInfo instance")
    }
    
    /// Initializer with a default peripheral identifier
    init(defaultPeripheralId: String?) {
        self.defaultPeripheralId = defaultPeripheralId
        print("[AppInfo] Init: Creating AppInfo with default peripheral ID: \(defaultPeripheralId ?? "nil")")
    }
    
    /// Helper method to set the default peripheral from a CBPeripheral object
    func setDefaultPeripheral(_ peripheral: CBPeripheral?) {
        self.defaultPeripheralId = peripheral?.identifier.uuidString
        print("[AppInfo] Setting default peripheral ID: \(defaultPeripheralId ?? "nil")")
    }
    
    /// Helper method to get the default peripheral by UUID from a central manager
    func getDefaultPeripheral(centralManager: CBCentralManager) -> CBPeripheral? {
        guard let idString = defaultPeripheralId, let uuid = UUID(uuidString: idString) else {
            return nil
        }
        
        // Try to retrieve the peripheral by UUID
        return centralManager.retrievePeripherals(withIdentifiers: [uuid]).first
    }
}
