//
//  ContentView.swift
//  AccessoryDemo
//
//  Created by Per Friis on 12/09/2024.
//

import SwiftUI

struct ContentView: View {
    @Environment(AccessoryController.self) private var controller

    var body: some View {
        VStack {
            if let accessory = controller.bleAccessory,
               accessory.peripheralConnected
            {
                XaioEsp32View(accessory: accessory)
            } else {
                Button("Open Accessory") {
                    Task {
                        try? await controller.presentPicker()
                    }
                }
            }
        }
    }

}

#Preview {
    ContentView()
        .environment(AccessoryController())

}
