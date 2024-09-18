//
//  AccessoryDemoApp.swift
//  AccessoryDemo
//
//  Created by Per Friis on 12/09/2024.
//

import SwiftUI

@main
struct AccessoryDemoApp: App {
    @State private var controller = AccessoryController()
        var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(controller)
    }
}
