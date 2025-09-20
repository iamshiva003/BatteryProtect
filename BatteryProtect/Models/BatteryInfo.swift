//
//  BatteryInfo.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import Foundation

struct BatteryInfo {
    let level: Float
    let powerSource: String
    let chargingStatus: String
    let health: String
    let healthPercentage: Int
    let lastUpdateTime: Date
    // New: integer percentage aligned with system UI
    let systemPercentage: Int

    init(
        level: Float = 1.0,
        powerSource: String = "Unknown",
        chargingStatus: String = "Unknown",
        health: String = "Unknown",
        healthPercentage: Int = 100,
        lastUpdateTime: Date = Date(),
        systemPercentage: Int = 100
    ) {
        self.level = level
        self.powerSource = powerSource
        self.chargingStatus = chargingStatus
        self.health = health
        self.healthPercentage = healthPercentage
        self.lastUpdateTime = lastUpdateTime
        self.systemPercentage = systemPercentage
    }
}

extension BatteryInfo {
    var isCharging: Bool {
        chargingStatus == "Charging"
    }
    
    var isPluggedIn: Bool {
        powerSource == "Power Adapter"
    }
    
    var isLowBattery: Bool {
        let lowThreshold = UserDefaults.standard.object(forKey: "lowBatteryThreshold") as? Double ?? 20.0
        return level <= Float(lowThreshold / 100.0)
    }
    
    var isHighBattery: Bool {
        let highThreshold = UserDefaults.standard.object(forKey: "highBatteryThreshold") as? Double ?? 80.0
        return level >= Float(highThreshold / 100.0)
    }
    
    var isCriticalBattery: Bool {
        let lowThreshold = UserDefaults.standard.object(forKey: "lowBatteryThreshold") as? Double ?? 20.0
        return level <= Float((lowThreshold - 5.0) / 100.0) // 5% below low threshold
    }
    
    var batteryIcon: String {
        if level <= 0.05 {
            return "battery.0.circle.fill"
        } else if level <= 0.25 {
            return "battery.25.circle.fill"
        } else if level <= 0.50 {
            return "battery.50.circle.fill"
        } else if level <= 0.75 {
            return "battery.75.circle.fill"
        } else {
            return "battery.100.circle.fill"
        }
    }
    
    var batteryColor: String {
        let lowThreshold = UserDefaults.standard.object(forKey: "lowBatteryThreshold") as? Double ?? 20.0
        let criticalThreshold = Float((lowThreshold - 5.0) / 100.0)
        let lowThresholdFloat = Float(lowThreshold / 100.0)
        
        if level <= criticalThreshold {
            return "red"
        } else if level <= lowThresholdFloat {
            return "orange"
        } else if isPluggedIn {
            return "green"
        } else {
            return "orange"
        }
    }
    
    var healthIcon: String {
        if healthPercentage >= 90 {
            return "heart.fill"
        } else if healthPercentage >= 80 {
            return "heart"
        } else if healthPercentage >= 60 {
            return "heart.slash"
        } else {
            return "heart.slash.fill"
        }
    }
    
    var healthTooltip: String {
        "Battery health: \(healthPercentage)% of original capacity"
    }
    
    // Convenience for UI display
    var displayPercentage: Int {
        systemPercentage
    }
} 
