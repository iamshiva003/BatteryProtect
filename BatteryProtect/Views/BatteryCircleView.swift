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
    
    // Use the exact system integer for all arc math to avoid any drift
    private var exactFraction: CGFloat {
        CGFloat(Float(batteryInfo.displayPercentage) / 100.0)
    }
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(backgroundColor, lineWidth: 8)
                .frame(width: 100, height: 100)
            
            // Progress Circle - driven by exact system integer percentage
            Circle()
                .trim(from: 0, to: exactFraction)
                .stroke(
                    powerColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                // Disable animation to prevent interpolation artifacts
                .animation(nil, value: batteryInfo.displayPercentage)
            
            // Battery Level Text - same integer
            VStack(spacing: 1) {
                Text("\(batteryInfo.displayPercentage)%")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(powerColor)
                    .animation(nil, value: batteryInfo.displayPercentage)
                
                if let text = timeText(info: batteryInfo) {
                    Text(text)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(Color.secondaryTextColor(for: colorScheme))
                }
                
                Text(batteryInfo.chargingStatus)
                    .font(.caption2)
                    .foregroundColor(Color.secondaryTextColor(for: colorScheme))
                    .animation(nil, value: batteryInfo.chargingStatus)
            }
        }
    }
    
    private func timeText(info: BatteryInfo) -> String? {
        if info.isCharging, let minutes = info.timeToFullChargeMinutes {
            return "~" + format(minutes: minutes)
        }
        if !info.isPluggedIn, let minutes = info.timeToEmptyMinutes {
            return "~" + format(minutes: minutes)
        }
        return nil
    }
    
    private func format(minutes: Int) -> String {
        let hrs = minutes / 60
        let mins = minutes % 60
        if hrs > 0 {
            return "\(hrs)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
