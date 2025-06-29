//
//  CBUUIDs.swift
//  usersApp
//
//  Created by Sofija Zolotarev on 30.4.25..
//

import CoreBluetooth
import Foundation

//stuff from BLE_CBUUID
let CBUID_deviceInfoService = CBUUID(string: "180A")
let CBUID_batterySensorService = CBUUID(string: "180F")
let CBUID_batteryLevel = CBUUID(string: "2A19")
    
let AMS_Service = CBUUID(string: "59462F12-9543-9999-12C8-58B459A2712D")
let AMS_WriteService = CBUUID(string: "60462F12-9543-9999-12C8-58B459A2712D")
let CBUID_sendCommand = CBUUID(string: "5C3A659E-897E-45E1-B016-007107C96DF7")
let CBUID_MemoryAvailableOnCard = CBUUID(string: "6B3A659E-897E-45E1-B016-007107C96DF7")
let CBUID_SessionNr = CBUUID(string: "703A659E-897E-45E1-B016-007107C96DF7")
let CBUID_StudyID = CBUUID(string: "6F3A659E-897E-45E1-B016-007107C96DF7")
let CBUID_PP_ID = CBUUID(string: "6D3A659E-897E-45E1-B016-007107C96DF7")
let CBUID_LooseElectrodeDetection = CBUUID(string: "6A3A659E-897E-45E1-B016-007107C96DF7")

