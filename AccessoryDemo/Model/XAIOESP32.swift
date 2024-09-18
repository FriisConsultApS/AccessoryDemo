//
//  XAIOESP32.swift
//  AccessoryDemo
//
//  Created by Per Friis on 17/09/2024.
//

import Foundation
import AccessorySetupKit
import CoreBluetooth
import SwiftUI
import OSLog

/// The main XAIO ESP32 device, there is serval sub models. this class can be subclassed to creat variations
@Observable class XAIOESP32: NSObject, BleAccesssory {
    var isRolling: Bool = true
    var value: Int = 0
    var peripheralConnected: Bool = false
    var image: Image { Image(Self.imageName)}
    var title: String { Self.name }
    
    internal var status: XAIOStatus = []
    
    private var initContinuation: CheckedContinuation<Void, Error>?
    
    private var accessory: ASAccessory
    
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral!
    private var rollDiceChar: CBCharacteristic?
    private var sleepChar: CBCharacteristic?
    
    internal var debugLog = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "\(XAIOESP32.self)")
    
    /// Setup the Peripheral with all the services and characteristics
    /// - Parameters: accessory The selected Accessory Device to connect to..
    required init(accessory: ASAccessory) async throws(BleAccesssoryError) {
        self.accessory = accessory
        super.init()
        self.debugLog.info("Initializing XAIOESP32")
        
        let timeOut = Task.detached { [weak self] in
            try await Task.sleep(for: .seconds(20))
            if Task.isCancelled {
                self?.debugLog.info("The timeout function was cancelled")
                return
            }
            
            
            self?.debugLog.info("Timeout waiting for services: \(self?.status.rawValue == 0)")
            self?.initContinuation?.resume(throwing: BleAccesssoryError.timeout )
        }
        
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.initContinuation = continuation
                self.central = CBCentralManager(delegate: self, queue: nil)
            }
            
        } catch let error as BleAccesssoryError {
            debugLog.error("Error during initialization: \(error as NSError)")
            throw error
        } catch {
            debugLog.error("General error during initialization: \(error as NSError)")
            throw .parsthrough(error)
        }
        timeOut.cancel()
        initContinuation = nil
    }
    
    func powerOff() {
        guard let sleepChar else { return }
        peripheral.writeValue(Data([1]), for: sleepChar, type: .withResponse)
    }
    
    func rollDice() {
        guard initContinuation == nil else { return }
        self.isRolling = true
        self.value = 0
        
        guard let rollDiceChar else { return }
        
        peripheral.writeValue(Data([0]), for: rollDiceChar, type: .withResponse)
    }
    
    /// Disconnect the accessory
    func disconnect() {
        initContinuation?.resume(throwing: BleAccesssoryError.peripheralNotFound)
        initContinuation = nil
        central.cancelPeripheralConnection(peripheral)
    }
}

extension XAIOESP32: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            debugLog.info("Bluetooth is powered on")
            central.scanForPeripherals(withServices: Self.services, options: nil)
            if peripheral == nil,
               let peripheralId = accessory.bluetoothIdentifier,
               let peripheral = central.retrievePeripherals(withIdentifiers: [peripheralId]).first {
                self.peripheral = peripheral
            }
            guard peripheral != nil else {
                initContinuation?.resume(throwing: BleAccesssoryError.peripheralNotFound)
                return
            }
            central.connect(peripheral, options: nil)
            
        case .unsupported, .unauthorized:
            initContinuation?.resume(throwing: BleAccesssoryError.peripheralNotSupported)

        default:
            debugLog.critical("BLE central manager state: \(central.state.description)")
            
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugLog.info("Connected to peripheral")
        peripheral.delegate = self
        peripheral.discoverServices(Self.services)
        peripheralConnected = true
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        peripheralConnected = false
        if let error {
            debugLog.error("Error disconnecting peripheral: \(error as NSError)")
            return
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        initContinuation?.resume(throwing: BleAccesssoryError.peripheralNotFound)
        initContinuation = nil
        peripheralConnected = false
        if let error {
            debugLog.error("Error connecting peripheral: \(error as NSError)")
            return
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        debugLog.info("Restoring state: \(dict)")
        assertionFailure("didnt see this comming")
    }
}


extension XAIOESP32: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        if let error {
            debugLog.error("Error discovering services: \(error as NSError)")
            initContinuation?.resume(throwing: error)
            initContinuation = nil
            return
        }
        
        guard let services = peripheral.services else {
            debugLog.error("No services found")
            initContinuation?.resume(throwing: BleAccesssoryError.noServices)
            initContinuation = nil
            return
        }
        
        services.forEach { service in
            switch service.uuid {
            case Self.diceService:
                peripheral.discoverCharacteristics(Self.diceCharacteristics, for: service)
                status.insert(.diceService)
            
            case Self.powerService:
                peripheral.discoverCharacteristics([Self.sleepChar], for: service)
                status.insert(.powerService)
                
            default:
                debugLog.info("Unknown service: \(service.uuid)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        if let error {
            debugLog.error("Error discovering characteristics: \(error as NSError)")
            initContinuation?.resume(throwing: error)
            initContinuation = nil
            return
        }
        
        guard let characteristics = service.characteristics else {
            debugLog.error("No characteristics found")
            initContinuation?.resume(throwing: BleAccesssoryError.noChar)
            return
        }
        
        characteristics.forEach { characteristic in
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            
            switch characteristic.uuid {
            case Self.rollDiceChar:
                self.rollDiceChar = characteristic
                self.status.insert(.diceChar)
                
            case Self.sleepChar:
                self.sleepChar = characteristic
                self.status.insert(.sleepChar)
                
                
            default:
                debugLog.info("Unknown characteristic: \(characteristic.uuid)")
            }
        }
 
        if status == .ready {
            initContinuation?.resume()
            initContinuation = nil
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error {
            debugLog.error("Error updating value for characteristic: \(error as NSError)")
            return
        }
        
        switch characteristic.uuid {
        case Self.diceRolledChar:
            guard let data = characteristic.value else { return }
            self.value = Int(data.first!)
            self.isRolling = false
            
        default:
            debugLog.info("Unknown characteristic: \(characteristic.uuid): \(characteristic.value?.string ?? "")")
        }
    }
}


extension Data {
    var string: String {
        String(data: self, encoding: .utf8) ?? hex
    }

    var hex: String { map { String(format: "%02X", $0)}.joined(separator: ":")}
    var bin: String { map { String($0, radix: 2)}.joined(separator: ":")}
}


extension XAIOESP32 {
    struct XAIOStatus: OptionSet {
        let rawValue: UInt8
        
        static let powerService = XAIOStatus(rawValue: 1 << 0)
        static let sleepChar = XAIOStatus(rawValue: 1 << 1)
        static let diceService = XAIOStatus(rawValue: 1 << 2)
        static let diceChar = XAIOStatus(rawValue: 1 << 3)
        
        static let ready: XAIOStatus = [.powerService, .sleepChar, .diceService, .diceChar]
    }
    
    static var pickerItem: ASPickerDisplayItem {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = xaioEsp32Service
        descriptor.bluetoothRange = .immediate
        
        return ASPickerDisplayItem(name: name,
                                   productImage: UIImage(named: imageName)!,
                                   descriptor: descriptor)
    }

    private static let name = "Seeed XAIO ESP32"
    private static let imageName = "XAIO-ESP32-S3"
    
    private static let xaioEsp32Service = CBUUID(string:"B95A2DD0-DD96-4AEB-8284-CE317BD7D3A1") // could be it's own
    
    private static let powerService = CBUUID(string: "B95A2DD0-DD96-4AEB-8284-CE317BD7D3E0")
    private static let sleepChar = CBUUID(string: "B95A2DD0-DD96-4AEB-8284-CE317BD7D3E1")
    
    private static let diceService = CBUUID(string: "B95A2DD0-DD96-4AEB-8284-CE317BD7D3FF")
    private static let diceCharacteristics = [rollDiceChar, diceRolledChar]
    
    /// the uuid to rolling dice characteristic
    /// - note: the UUID need to be changed to a full uuid
    private static let rollDiceChar = CBUUID(string: "FFA0")
    
    /// the uuid characteristic that are called when the dice has rolled
    /// - note: the UUID need to be changed to a full uuid
    private static let diceRolledChar = CBUUID(string: "FFA1")
    
    
    private static let services: [CBUUID] = [deviceInformationService, diceService, powerService]
    
    // MARK: stuff to evaluate
    private static let xaioEsp32S3Service = CBUUID(string:"B95A2DD0-DD96-4AEB-8284-CE317BD7D3A0")
    private static let xaioEsp32S3EBBService = CBUUID(string:"B95A2DD0-DD96-4AEB-8284-CE317BD7D3B0")
    private static let xaioEsp32C3Service = CBUUID(string:"B95A2DD0-DD96-4AEB-8284-CE317BD7D3A1")
    private static let xaioEsp32C3EBBService = CBUUID(string:"B95A2DD0-DD96-4AEB-8284-CE317BD7D3B1")
    private static let arduinoNanoBLEService = CBUUID(string:"B95A2DD0-DD96-4AEB-8284-CE317BD7D3A2")
    private static let coloplastService = CBUUID(string:"CC7314CC-003C-40B2-9372-4881E4805672")
    private static let naviCapService = CBUUID(string:"AA80")
    //static let naviCapService = CBUUID(string:"E4E8A8E5-934A-454D-AAE8-61105A1EC2D5")
    
    

    private static let deviceInformationService = CBUUID(string: "180A")
    private static let serialNumberChar         = CBUUID(string: "2A25")
    private static let firmwareVersion          = CBUUID(string: "2A26")
    private static let hardwareVersion          = CBUUID(string: "2A27")

    private static let batteryService           = CBUUID(string: "180F")
    private static let batteryChar              = CBUUID(string: "2A19")

}


extension CBManagerState: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: "Unknown"
        case .resetting: "Resetting"
        case .unsupported: "Unsupported"
        case .unauthorized: "Unauthorized"
        case .poweredOff: "Powered Off"
        case .poweredOn: "Powered On"
        @unknown default:
            "new unknown state"
        }
    }
}
