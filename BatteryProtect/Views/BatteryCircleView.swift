//
//  BatteryCircleView.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI

struct BatteryCircleView: View {
    let batteryInfo: BatteryInfo
    let colorScheme: ColorScheme
    @State private var isAnimating: Bool = false
    
    private var powerColor: Color {
        Color.batteryColor(for: batteryInfo, colorScheme: colorScheme)
    }
    
    private var backgroundColor: Color {
        Color.backgroundColor(for: colorScheme)
    }
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(backgroundColor, lineWidth: 8)
                .frame(width: 100, height: 100)
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: CGFloat(batteryInfo.level))
                .stroke(
                    powerColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                .animation(.spring(dampingFraction: 0.7), value: batteryInfo.level)
            
            // Charging indicator (static)
            if batteryInfo.isPluggedIn && batteryInfo.isCharging {
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(powerColor.opacity(0.5), lineWidth: 8)
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(0))
            }
            
            // Battery Level Text
            VStack(spacing: 1) {
                Text("\(Int(batteryInfo.level * 100))%")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(powerColor)
                    .animation(.spring(), value: batteryInfo.level)
                
                Text(batteryInfo.chargingStatus)
                    .font(.caption2)
                    .foregroundColor(Color.secondaryTextColor(for: colorScheme))
                    .animation(.easeInOut, value: batteryInfo.chargingStatus)
                    .transition(.scale.combined(with: .opacity))
            }
        }

    }
} 