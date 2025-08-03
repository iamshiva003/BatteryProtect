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
    
    // MARK: - Performance Optimizations
    private var timer: Timer?
    private var lastAlertTime: Date = Date.distantPast
    private var lastBatteryState: (level: Float, pluggedIn: Bool) = (1.0, false)
    private var lastBatteryInfo: BatteryInfo?
    private var isMonitoring = false
    
    // Adaptive polling intervals - optimized for faster response
    private let fastPollingInterval: TimeInterval = 1.0  // Reduced from 2.0
    private let slowPollingInterval: TimeInterval = 5.0  // Reduced from 10.0
    private let backgroundPollingInterval: TimeInterval = 15.0 // Reduced from 30.0
    
    // Power source change detection
    private var lastPowerSource: String = ""
    private var powerSourceChangeTimer: Timer?
    
    // Memory management
    private var notificationQueue = DispatchQueue(label: "com.batteryprotect.notifications", qos: .utility)
    private var batteryInfoCache: [String: Any] = [:]
    
    init() {
        requestNotificationPermission()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        updateBatteryStatus()
        startAdaptivePolling()
        
        // Start power source change detection
        startPowerSourceMonitoring()
    }
    
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        powerSourceChangeTimer?.invalidate()
        powerSourceChangeTimer = nil
        batteryInfoCache.removeAll()
    }
    
    private func startAdaptivePolling() {
        // Use adaptive polling based on system state
        let interval = getOptimalPollingInterval()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
    }
    
    private func startPowerSourceMonitoring() {
        // Monitor power source changes more frequently
        powerSourceChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPowerSourceChange()
        }
    }
    
    private func checkPowerSourceChange() {
        let currentPowerSource = getCurrentPowerSource()
        
        if currentPowerSource != lastPowerSource {
            // Power source changed - update immediately
            lastPowerSource = currentPowerSource
            updateBatteryStatus()
            
            // Temporarily increase polling frequency for faster response
            increasePollingFrequency()
        }
    }
    
    private func getCurrentPowerSource() -> String {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources: NSArray = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue()
        
        guard let source = sources.firstObject else {
            return "Unknown"
        }
        
        let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef).takeUnretainedValue() as? [String: Any]
        return description?[kIOPSPowerSourceStateKey as String] as? String ?? "Unknown"
    }
    
    private func increasePollingFrequency() {
        // Temporarily increase polling to 0.5 seconds for 10 seconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
        
        // Reset to normal polling after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.resetToNormalPolling()
        }
    }
    
    private func resetToNormalPolling() {
        guard isMonitoring else { return }
        
        let interval = getOptimalPollingInterval()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
    }
    
    private func getOptimalPollingInterval() -> TimeInterval {
        // Adaptive polling based on battery state and system activity
        if let batteryInfo = lastBatteryInfo {
            // Fast polling when battery is critical or charging
            if batteryInfo.isCriticalBattery || batteryInfo.isCharging {
                return fastPollingInterval
            }
            
            // Slow polling when battery is stable
            if batteryInfo.level > 0.3 && !batteryInfo.isPluggedIn {
                return slowPollingInterval
            }
        }
        
        return fastPollingInterval
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func updateBatteryStatus() {
        guard isMonitoring else { return }
        
        let newBatteryInfo = getBatteryInfo()
        let pluggedIn = newBatteryInfo.isPluggedIn
        
        // Always update UI for power source changes
        let shouldUpdate = shouldUpdateUI(newBatteryInfo: newBatteryInfo) || 
                          newBatteryInfo.powerSource != (lastBatteryInfo?.powerSource ?? "")
        
        if shouldUpdate {
            DispatchQueue.main.async { [weak self] in
                self?.batteryInfo = newBatteryInfo
            }
        }
        
        // Check for alerts
        checkBatteryAlerts(level: newBatteryInfo.level, pluggedIn: pluggedIn)
        
        // Update polling interval if needed
        updatePollingIntervalIfNeeded(newBatteryInfo: newBatteryInfo)
        
        lastBatteryInfo = newBatteryInfo
    }
    
    private func shouldUpdateUI(newBatteryInfo: BatteryInfo) -> Bool {
        guard let lastInfo = lastBatteryInfo else { return true }
        
        // Update if battery level changed by more than 1%
        let levelDifference = abs(newBatteryInfo.level - lastInfo.level)
        if levelDifference > 0.01 {
            return true
        }
        
        // Update if charging status changed
        if newBatteryInfo.isCharging != lastInfo.isCharging {
            return true
        }
        
        // Update if power source changed
        if newBatteryInfo.powerSource != lastInfo.powerSource {
            return true
        }
        
        // Update every 15 seconds regardless (reduced from 30)
        let timeSinceLastUpdate = Date().timeIntervalSince(lastInfo.lastUpdateTime)
        return timeSinceLastUpdate > 15
    }
    
    private func updatePollingIntervalIfNeeded(newBatteryInfo: BatteryInfo) {
        let currentInterval = timer?.timeInterval ?? fastPollingInterval
        let optimalInterval = getOptimalPollingInterval()
        
        if abs(currentInterval - optimalInterval) > 0.1 {
            timer?.invalidate()
            startAdaptivePolling()
        }
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
        notificationQueue.async {
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
    }
    
    private func getBatteryInfo() -> BatteryInfo {
        // Use cached battery info if available and recent (reduced cache time for faster updates)
        if let cachedInfo = getCachedBatteryInfo(), 
           Date().timeIntervalSince(cachedInfo.lastUpdateTime) < 2.0 { // Reduced from 5.0
            return cachedInfo
        }
        
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
        
        let batteryInfo = BatteryInfo(
            level: batteryLevel,
            powerSource: formattedPowerSource,
            chargingStatus: chargingStatus,
            health: health,
            healthPercentage: healthPercentage,
            lastUpdateTime: Date()
        )
        
        // Cache the result
        cacheBatteryInfo(batteryInfo)
        
        return batteryInfo
    }
    
    private func cacheBatteryInfo(_ batteryInfo: BatteryInfo) {
        batteryInfoCache["lastBatteryInfo"] = batteryInfo
        batteryInfoCache["lastUpdateTime"] = Date()
    }
    
    private func getCachedBatteryInfo() -> BatteryInfo? {
        return batteryInfoCache["lastBatteryInfo"] as? BatteryInfo
    }
} 