//
//  Item.swift
//  AccessoryDemo
//
//  Created by Per Friis on 12/09/2024.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
