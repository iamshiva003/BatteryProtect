//
//  SettingsButtonView.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI
import AppKit

struct SettingsButtonView: View {
    let colorScheme: ColorScheme
    @State private var isHovering: Bool = false
    
    private var iconColor: Color {
        Color.subtleTextColor(for: colorScheme)
    }
    
    private var backgroundColor: Color {
        Color.mainBackgroundColor(for: colorScheme)
    }
    
    private var borderColor: Color {
        Color.mainBorderColor(for: colorScheme)
    }
    
    var body: some View {
        Button(action: openSystemBatterySettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(iconColor)
                .padding(6)
                .background(
                    Circle()
                        .fill(isHovering ? backgroundColor : Color.clear)
                        .overlay(
                            Circle()
                                .stroke(isHovering ? borderColor : Color.clear, lineWidth: 1)
                        )
                )
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .help("Open System Battery Settings")
    }
    
    private func openSystemBatterySettings() {
        // Open System Preferences > Battery
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    SettingsButtonView(colorScheme: .light)
        .padding()
} 