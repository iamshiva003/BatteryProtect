//
//  ColorExtensions.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI

extension Color {
    static func batteryColor(for batteryInfo: BatteryInfo, colorScheme: ColorScheme) -> Color {
        if batteryInfo.isCriticalBattery {
            return .red
        } else if batteryInfo.isLowBattery {
            return .orange
        } else if batteryInfo.isPluggedIn {
            return .green
        } else {
            return .orange
        }
    }
    
    static func healthColor(for batteryInfo: BatteryInfo, baseColor: Color) -> Color {
        if batteryInfo.healthPercentage >= 90 {
            return baseColor
        } else if batteryInfo.healthPercentage >= 80 {
            return baseColor.opacity(0.8)
        } else if batteryInfo.healthPercentage >= 60 {
            return baseColor.opacity(0.6)
        } else {
            return baseColor.opacity(0.4)
        }
    }
    
    static func backgroundColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)
    }
    
    static func mainBackgroundColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.95)
    }
    
    static func mainBorderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.1)
    }
    
    static func textColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.95) : .black.opacity(0.85)
    }
    
    static func secondaryTextColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.6)
    }
    
    static func subtleTextColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.45)
    }
    
    static func pillBackgroundColor(for baseColor: Color, colorScheme: ColorScheme) -> Color {
        baseColor.opacity(colorScheme == .dark ? 0.35 : 0.15)
    }
    
    static func pillBorderColor(for baseColor: Color, colorScheme: ColorScheme) -> Color {
        baseColor.opacity(colorScheme == .dark ? 0.4 : 0.25)
    }
} 