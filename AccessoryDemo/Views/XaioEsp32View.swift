//
//  XaioEsp32View.swift
//  AccessoryDemo
//
//  Created by Per Friis on 17/09/2024.
//

import SwiftUI

struct XaioEsp32View: View {
    var accessory: BleAccesssory
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    accessory.powerOff()
                } label: {
                    Image(systemName: "poweroff")
                }
            }
            Text(accessory.title)
            accessory.image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 86)
                .opacity(accessory.peripheralConnected ? 1.0 : 0.25)
                .padding()
                .background(.thinMaterial, in: Circle())
            
            Button {
                accessory.rollDice()
            } label: {
                if accessory.isRolling {
                    ProgressView()
                        .controlSize(.extraLarge)
                        .frame(width: 144, height: 144)
                } else {
                    Text("\(accessory.value)")
                        .font(.system(size: 144))
                        .monospaced()
                }
            }
            .buttonStyle(.plain)
            
            
        }
        .task {
            accessory.rollDice()
        }
    }
}

#Preview {
    XaioEsp32View(accessory: PreviewBleAccessory())
}
