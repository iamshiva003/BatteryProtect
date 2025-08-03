//
//  StatusPillsView.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI

struct StatusPillsView: View {
    let batteryInfo: BatteryInfo
    let colorScheme: ColorScheme
    @State private var isHovering: Bool = false
    @State private var isHealthHovering: Bool = false
    
    private var powerColor: Color {
        Color.batteryColor(for: batteryInfo, colorScheme: colorScheme)
    }
    
    private var healthColor: Color {
        Color.healthColor(for: batteryInfo, baseColor: powerColor)
    }
    
    private var pillBackgroundColor: Color {
        Color.pillBackgroundColor(for: powerColor, colorScheme: colorScheme)
    }
    
    private var healthPillBackgroundColor: Color {
        Color.pillBackgroundColor(for: healthColor, colorScheme: colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Power Source Pill
            HStack(spacing: 3) {
                Image(systemName: batteryInfo.isPluggedIn ? "poweroutlet.type.f" : "battery.100")
                    .font(.caption2)
                Text(batteryInfo.powerSource)
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(pillBackgroundColor)
                    .overlay(
                        Capsule()
                            .stroke(Color.pillBorderColor(for: powerColor, colorScheme: colorScheme), lineWidth: 1)
                    )
                    .scaleEffect(isHovering ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            )
            .foregroundColor(powerColor)
            .animation(.easeInOut, value: batteryInfo.powerSource)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
            }
            
            // Battery Health Pill
            HStack(spacing: 3) {
                Image(systemName: batteryInfo.healthIcon)
                    .font(.caption2)
                Text("\(batteryInfo.healthPercentage)%")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(healthPillBackgroundColor)
                    .overlay(
                        Capsule()
                            .stroke(Color.pillBorderColor(for: healthColor, colorScheme: colorScheme), lineWidth: 1)
                    )
                    .scaleEffect(isHealthHovering ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHealthHovering)
            )
            .foregroundColor(healthColor)
            .animation(.easeInOut, value: batteryInfo.healthPercentage)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHealthHovering = hovering
                }
            }
            .help(batteryInfo.healthTooltip)
        }
    }
} 