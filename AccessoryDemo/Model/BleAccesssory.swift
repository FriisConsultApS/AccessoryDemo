//
//  BLEAsseory.swift
//  AccessoryDemo
//
//  Created by Per Friis on 17/09/2024.
//

import Foundation
import AccessorySetupKit
import CoreBluetooth
import SwiftUI

protocol BleAccesssory {
    var value: Int { get }
    var isRolling: Bool { get }
    var peripheralConnected: Bool { get }
    var image: Image { get }
    var title: String { get }
    init (accessory: ASAccessory) async throws(BleAccesssoryError)
    func disconnect()
    
    func powerOff()
    func rollDice()
    
    static var pickerItem: ASPickerDisplayItem { get }
}


enum BleAccesssoryError: Error {
    case peripheralNotFound
    case peripheralNotConnected
    case peripheralNotAuthorized
    case peripheralNotSupported
    
    case timeout
    case parsthrough(Error)
    case noServices
    case noChar
}


@Observable class PreviewBleAccessory: BleAccesssory {
    var value: Int
    var isRolling: Bool
    var peripheralConnected: Bool
    var title: String = "Preview"
    var image: Image { .init(systemName: "arrow.2.circlepath.circle") }
    required init(accessory: ASAccessory) async throws(BleAccesssoryError) {
        value = 0
        peripheralConnected = true
        isRolling = true
    }
    
    init() {
        value = 0
        peripheralConnected = true
        isRolling = true
    }
    
    func disconnect() {
        peripheralConnected.toggle()
    }
    
    func powerOff() {
        peripheralConnected.toggle()
    }
    
    func rollDice() {
        Task { @MainActor in
            self.isRolling = true
            try? await Task.sleep(for: .seconds(3))
            self.value = Int.random(in: 1...6)
            self.isRolling = false
        }
    }
    
    static var pickerItem: ASPickerDisplayItem =
    ASPickerDisplayItem(name: "preview",
                               productImage: UIImage(named: "Arduino NANO BLE")!,
                        descriptor: .init())
        
    
    
    
    
}
