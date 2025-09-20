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
    private let fastPollingInterval: TimeInterval = 1.0
    private let slowPollingInterval: TimeInterval = 5.0
    private let backgroundPollingInterval: TimeInterval = 15.0
    
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
        let interval = getOptimalPollingInterval()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
    }
    
    private func startPowerSourceMonitoring() {
        powerSourceChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPowerSourceChange()
        }
    }
    
    private func checkPowerSourceChange() {
        let currentPowerSource = getCurrentPowerSource()
        if currentPowerSource != lastPowerSource {
            lastPowerSource = currentPowerSource
            updateBatteryStatus()
            increasePollingFrequency()
        }
    }
    
    private func getCurrentPowerSource() -> String {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources: NSArray = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue()
        guard let source = sources.firstObject else { return "Unknown" }
        let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef).takeUnretainedValue() as? [String: Any]
        return description?[kIOPSPowerSourceStateKey as String] as? String ?? "Unknown"
    }
    
    private func increasePollingFrequency() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
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
        if let batteryInfo = lastBatteryInfo {
            if batteryInfo.isCriticalBattery || batteryInfo.isCharging {
                return fastPollingInterval
            }
            if batteryInfo.level > 0.3 && !batteryInfo.isPluggedIn {
                return slowPollingInterval
            }
        }
        return fastPollingInterval
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .provisional]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else if granted {
                self.checkNotificationSettings()
            }
        }
    }
    
    private func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { _ in }
    }
    
    private func updateBatteryStatus() {
        guard isMonitoring else { return }
        let newBatteryInfo = getBatteryInfo()
        let pluggedIn = newBatteryInfo.isPluggedIn
        
        let shouldUpdate = shouldUpdateUI(newBatteryInfo: newBatteryInfo) ||
                           newBatteryInfo.powerSource != (lastBatteryInfo?.powerSource ?? "")
        
        if shouldUpdate {
            DispatchQueue.main.async { [weak self] in
                self?.batteryInfo = newBatteryInfo
            }
        }
        
        checkBatteryAlerts(level: newBatteryInfo.level, pluggedIn: pluggedIn)
        updatePollingIntervalIfNeeded(newBatteryInfo: newBatteryInfo)
        lastBatteryInfo = newBatteryInfo
    }
    
    private func shouldUpdateUI(newBatteryInfo: BatteryInfo) -> Bool {
        guard let lastInfo = lastBatteryInfo else { return true }
        let levelDifference = abs(newBatteryInfo.level - lastInfo.level)
        if levelDifference > 0.01 { return true }
        if newBatteryInfo.isCharging != lastInfo.isCharging { return true }
        if newBatteryInfo.powerSource != lastInfo.powerSource { return true }
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
        
        let enableLowBatteryAlerts = UserDefaults.standard.object(forKey: "enableLowBatteryAlerts") as? Bool ?? true
        let enableHighBatteryAlerts = UserDefaults.standard.object(forKey: "enableHighBatteryAlerts") as? Bool ?? true
        let lowBatteryThreshold = UserDefaults.standard.object(forKey: "lowBatteryThreshold") as? Double ?? 20.0
        let highBatteryThreshold = UserDefaults.standard.object(forKey: "highBatteryThreshold") as? Double ?? 80.0
        
        let lowThreshold = Float(lowBatteryThreshold / 100.0)
        let highThreshold = Float(highBatteryThreshold / 100.0)
        
        var shouldShowAlert = false
        var message = ""
        var title = ""
        
        if timeSinceLastAlert > 30 {
            if enableLowBatteryAlerts && level <= lowThreshold {
                title = "⚠️ Low Battery"
                message = "Battery level is low: \(Int((level * 100).rounded()))% (threshold: \(Int(lowBatteryThreshold))%)"
                shouldShowAlert = true
            } else if enableHighBatteryAlerts && level >= highThreshold && pluggedIn {
                title = "🔌 High Battery"
                message = "Battery level is high: \(Int((level * 100).rounded()))% (threshold: \(Int(highBatteryThreshold))%) - Consider unplugging to preserve battery health"
                shouldShowAlert = true
            }
        }
        
        if powerSourceChanged && !shouldShowAlert && timeSinceLastAlert > 5 {
            if enableLowBatteryAlerts && level <= lowThreshold {
                title = "⚠️ Low Battery"
                message = "Battery level is low: \(Int((level * 100).rounded()))% (threshold: \(Int(lowBatteryThreshold))%)"
                shouldShowAlert = true
            } else if enableHighBatteryAlerts && level >= highThreshold && pluggedIn {
                title = "🔌 High Battery"
                message = "Battery level is high: \(Int((level * 100).rounded()))% (threshold: \(Int(highBatteryThreshold))%) - Consider unplugging to preserve battery health"
                shouldShowAlert = true
            }
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
            content.interruptionLevel = .timeSensitive
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }
    
    private func getBatteryInfo() -> BatteryInfo {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources: NSArray = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue()
        
        // Prefer InternalBattery
        var selectedSource: CFTypeRef?
        for case let source as CFTypeRef in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any],
               let type = desc[kIOPSTypeKey as String] as? String,
               type == kIOPSInternalBatteryType {
                selectedSource = source
                break
            }
        }
        if selectedSource == nil {
            selectedSource = (sources.firstObject as AnyObject?) as? CFTypeRef
        }
        
        guard let source = selectedSource,
              let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] else {
            return BatteryInfo()
        }
        
        // Compute integer percentage from IOKit using current and max capacity if available
        var ioKitPercent: Int = 100
        if let current = description[kIOPSCurrentCapacityKey as String] as? Int,
           let max = description[kIOPSMaxCapacityKey as String] as? Int,
           max > 0 {
            ioKitPercent = Int((Double(current) / Double(max) * 100.0).rounded())
        } else if let currentAsPercent = description[kIOPSCurrentCapacityKey as String] as? Int {
            ioKitPercent = currentAsPercent
        }
        
        // Reconcile with pmset integer percentage (matches System Settings)
        let pmsetPercent = getSystemBatteryPercentage()
        let chosenPercent: Int
        if pmsetPercent > 0 && abs(pmsetPercent - ioKitPercent) >= 1 {
            chosenPercent = pmsetPercent
        } else {
            chosenPercent = ioKitPercent
        }
        
        // Derive level from the chosen integer to keep UI and arcs consistent
        let batteryLevel = max(0.0, min(1.0, Float(chosenPercent) / 100.0))
        
        // Power source state
        let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String ?? "Unknown"
        
        // Charging flags
        let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
        let isCharged = description[kIOPSIsChargedKey as String] as? Bool ?? false
        let isPresent = description["IsPresent"] as? Bool ?? true
        
        // Charging status string
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
        
        // Health percentage (IOKit MaxCapacity is already a percentage of design capacity on macOS battery API)
        let healthPercentage: Int = (description[kIOPSMaxCapacityKey as String] as? Int) ?? 100
        
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
            lastUpdateTime: Date(),
            systemPercentage: chosenPercent
        )
        
        return batteryInfo
    }
    
    // Parse system battery percentage using pmset
    private func getSystemBatteryPercentage() -> Int {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g", "batt"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }
            // Look for "xx%;"
            // Example: " -InternalBattery-0 (id=1234567) 87%; discharging; (no estimate) present: true"
            let tokens = output.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            for token in tokens {
                if token.hasSuffix("%;") || token.hasSuffix("%") {
                    let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: ";"))
                    if let percent = Int(trimmed.replacingOccurrences(of: "%", with: "")) {
                        return max(0, min(100, percent))
                    }
                }
            }
        } catch {
            // Ignore errors; fallback will be used
        }
        return 0
    }
} 
