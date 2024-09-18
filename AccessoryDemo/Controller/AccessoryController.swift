//
//  AccessoryController.swift
//  AccessoryDemo
//
//  Created by Per Friis on 12/09/2024.
//

import Foundation
import AccessorySetupKit
import CoreBluetooth
import OSLog


@Observable
class AccessoryController {

    var bleAccessory: BleAccesssory?

    internal var debugLog = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "\(AccessoryController.self)")

    private var currentAccessory: ASAccessory?
    private var session = ASAccessorySession()
    private var manager: CBCentralManager?

    /// Setup the accessorysetup session
     init() {
        self.session.activate(on: .main, eventHandler: handleSessionEvents(event:))
    }

    /// Show the Accessory
    func presentPicker() async throws {
        try await session.showPicker(for: [XAIOESP32.pickerItem])
    }


    /// use the disconnect to ensure that the controller get the message....
    func disconnect() {
        bleAccessory?.disconnect()
        self.bleAccessory = nil
    }

    /// Handle all the connection to the accessory
    private func handleSessionEvents(event: ASAccessoryEvent) {
        debugLog.info("handleSessionEvents: \(event.eventType.description)")
        switch event.eventType {
            
        case .accessoryAdded, .accessoryChanged:
            guard let accessory = event.accessory else { return }
            Task {
                do {
                    // TODO: need to check what type of accessory we are talking about.....
                    self.bleAccessory = try await XAIOESP32(accessory: accessory)
                } catch {
                    debugLog.error("error connecting to \(accessory): \(error as NSError)")
                }
            }
            debugLog.info("accessory added: \(accessory)")

        case .activated:
            guard let accessory = session.accessories.first else {
                return
            }
            Task {
                do {
                    self.bleAccessory = try await XAIOESP32(accessory: accessory)
                } catch {
                    debugLog.error("error connecting to \(accessory): \(error as NSError)")
                }
            }


        case .accessoryRemoved:
            debugLog.info("accessory removed")
            self.currentAccessory = nil
            self.manager = nil


        default:
            debugLog.error("unhandled event: \(event.eventType.rawValue)")
        }
    }

}

extension ASAccessoryEventType: @retroactive CustomStringConvertible, @retroactive CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .accessoryAdded:  "Accessory Added"
        case .accessoryRemoved:  "Accessory Removed"
        case .accessoryChanged:  "Accessory Changed"
        case .activated:  "Activated"
        case .invalidated:  "Invalidated"
        case .migrationComplete:  "Migration Complete"
        case .pickerDidDismiss:  "Picker Did Dismiss"
        case .pickerDidPresent:  "Picker Did Present"
        case .pickerSetupFailed:  "Picker Setup Failed"
        case .pickerSetupPairing:  "Picker Setup Pairing"
        case .pickerSetupBridging:  "Picker Setup Bridging"
        
        case .unknown:
            "unknown"
        case .pickerSetupRename:
            "pickSetupRename"
        @unknown default:
            "new unknown type"
        }
    }
    
    public var debugDescription: String { description }
}
