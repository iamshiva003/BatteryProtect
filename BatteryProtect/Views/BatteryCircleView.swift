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
            
            // Progress Circle - no animation while charging
            Circle()
                .trim(from: 0, to: CGFloat(batteryInfo.level))
                .stroke(
                    powerColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                .animation(batteryInfo.isCharging ? nil : .spring(dampingFraction: 0.7), value: batteryInfo.level)
            
            // Battery Level Text - no animation while charging
            VStack(spacing: 1) {
                Text("\(batteryInfo.displayPercentage)%")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(powerColor)
                    .animation(batteryInfo.isCharging ? nil : .spring(), value: batteryInfo.displayPercentage)
                
                Text(batteryInfo.chargingStatus)
                    .font(.caption2)
                    .foregroundColor(Color.secondaryTextColor(for: colorScheme))
                    .animation(batteryInfo.isCharging ? nil : .easeInOut, value: batteryInfo.chargingStatus)
            }
        }
        
    }
} 
