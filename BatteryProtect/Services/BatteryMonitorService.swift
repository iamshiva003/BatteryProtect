//
//  BatteryMonitorService.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import Foundation
import IOKit.ps
import AppKit
import UserNotifications

class BatteryMonitorService: ObservableObject {
    @Published var batteryInfo: BatteryInfo = BatteryInfo()
    
    private var timer: Timer?
    private var lastAlertTime: Date = Date.distantPast
    private var lastBatteryState: (level: Float, pluggedIn: Bool) = (1.0, false)
    
    init() {
        requestNotificationPermission()
    }
    
    func startMonitoring() {
        updateBatteryStatus()
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateBatteryStatus()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func updateBatteryStatus() {
        let newBatteryInfo = getBatteryInfo()
        let pluggedIn = newBatteryInfo.isPluggedIn
        
        DispatchQueue.main.async {
            self.batteryInfo = newBatteryInfo
        }
        
        checkBatteryAlerts(level: newBatteryInfo.level, pluggedIn: pluggedIn)
    }
    
    private func checkBatteryAlerts(level: Float, pluggedIn: Bool) {
        let now = Date()
        let timeSinceLastAlert = now.timeIntervalSince(lastAlertTime)
        
        let powerSourceChanged = pluggedIn != lastBatteryState.pluggedIn
        
        let shouldShowLowBatteryAlert = level <= 0.2 && timeSinceLastAlert > 30
        let shouldShowHighBatteryAlert = level >= 0.8 && pluggedIn && timeSinceLastAlert > 30
        let shouldShowPowerSourceAlert = powerSourceChanged && ((level <= 0.2) || (level >= 0.8 && pluggedIn))
        
        var shouldShowAlert = false
        var message = ""
        var title = ""
        
        if shouldShowLowBatteryAlert {
            title = "⚠️ Low Battery"
            message = "Battery level is low: \(Int(level * 100))%"
            shouldShowAlert = true
        } else if shouldShowHighBatteryAlert {
            title = "🔌 High Battery"
            message = "Battery level is high: \(Int(level * 100))% - Consider unplugging to preserve battery health"
            shouldShowAlert = true
        } else if shouldShowPowerSourceAlert {
            if level <= 0.2 {
                title = "⚠️ Low Battery"
                message = "Battery level is low: \(Int(level * 100))%"
            } else if level >= 0.8 && pluggedIn {
                title = "🔌 High Battery"
                message = "Battery level is high: \(Int(level * 100))% - Consider unplugging to preserve battery health"
            }
            shouldShowAlert = true
        }
        
        if shouldShowAlert {
            showNotification(title: title, message: message)
            lastAlertTime = now
        }
        
        lastBatteryState = (level, pluggedIn)
    }
    
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
    
    private func getBatteryInfo() -> BatteryInfo {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources: NSArray = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue()
        
        guard let source = sources.firstObject else {
            return BatteryInfo()
        }
        
        let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef).takeUnretainedValue() as? [String: Any]
        
        // Get battery level
        var batteryLevel: Float = 1.0
        if let currentCapacity = description?[kIOPSCurrentCapacityKey as String] as? Int,
           let maxCapacity = description?[kIOPSMaxCapacityKey as String] as? Int,
           maxCapacity > 0 {
            batteryLevel = Float(currentCapacity) / Float(maxCapacity)
        }
        
        // Get power source state
        let powerSourceState = description?[kIOPSPowerSourceStateKey as String] as? String ?? "Unknown"
        
        // Get charging status
        let isCharging = description?[kIOPSIsChargingKey as String] as? Bool ?? false
        let isCharged = description?[kIOPSIsChargedKey as String] as? Bool ?? false
        let isPresent = description?["IsPresent"] as? Bool ?? true
        
        // Determine charging status string
        let chargingStatus: String
        if !isPresent {
            chargingStatus = "No Battery"
        } else if isCharged {
            chargingStatus = "Charged"
        } else if isCharging {
            chargingStatus = "Charging"
        } else if powerSourceState == kIOPSACPowerValue {
            chargingStatus = "Not Charging"
        } else if powerSourceState == kIOPSBatteryPowerValue {
            chargingStatus = "Discharging"
        } else {
            chargingStatus = "Unknown"
        }
        
        // Get battery health percentage
        let healthPercentage: Int
        if let maxCapacity = description?[kIOPSMaxCapacityKey as String] as? Int {
            healthPercentage = maxCapacity
        } else {
            healthPercentage = 100
        }
        
        // Get battery health description
        let health: String
        if healthPercentage >= 90 {
            health = "Excellent"
        } else if healthPercentage >= 80 {
            health = "Good"
        } else if healthPercentage >= 60 {
            health = "Fair"
        } else {
            health = "Poor"
        }
        
        // Format power source
        let formattedPowerSource: String
        switch powerSourceState {
        case kIOPSACPowerValue:
            formattedPowerSource = "Power Adapter"
        case kIOPSBatteryPowerValue:
            formattedPowerSource = "Battery"
        default:
            formattedPowerSource = powerSourceState
        }
        
        return BatteryInfo(
            level: batteryLevel,
            powerSource: formattedPowerSource,
            chargingStatus: chargingStatus,
            health: health,
            healthPercentage: healthPercentage,
            lastUpdateTime: Date()
        )
    }
} 