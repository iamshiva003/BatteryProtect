//
//  BatteryMonitorService.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import Foundation
import IOKit.ps
import IOKit
import AppKit
import UserNotifications

class BatteryMonitorService: ObservableObject {
    @Published var batteryInfo: BatteryInfo = BatteryInfo()
    
    // MARK: - Performance and responsiveness
    private var timer: Timer?
    private var lastAlertTime: Date = Date.distantPast
    private var lastBatteryState: (level: Float, pluggedIn: Bool) = (1.0, false)
    private var lastBatteryInfo: BatteryInfo?
    private var isMonitoring = false
    
    // Aggressive but safe intervals to reduce visible lag
    private let fastPollingInterval: TimeInterval = 0.5
    private let slowPollingInterval: TimeInterval = 2.0
    private let backgroundPollingInterval: TimeInterval = 5.0
    
    // IOKit push notifications
    private var runLoopSource: CFRunLoopSource?
    
    // Power source change detection (kept as a secondary mechanism)
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
        tearDownIOKitNotifications()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        setupIOKitNotifications()
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
        tearDownIOKitNotifications()
    }
    
    // MARK: - IOKit notifications (push-driven updates)
    private func setupIOKitNotifications() {
        guard runLoopSource == nil else { return }
        
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let callback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let `self` = Unmanaged<BatteryMonitorService>.fromOpaque(context).takeUnretainedValue()
            self.handlePowerSourceNotification()
        }
        
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
    }
    
    private func tearDownIOKitNotifications() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }
    
    private func handlePowerSourceNotification() {
        // Immediate update on any battery/power source change
        updateBatteryStatus()
        // Temporarily increase polling frequency to catch rapid transitions
        increasePollingFrequency()
    }
    
    // MARK: - Polling (fallback and adaptive)
    private func startAdaptivePolling() {
        let interval = getOptimalPollingInterval()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
    }
    
    private func startPowerSourceMonitoring() {
        powerSourceChangeTimer?.invalidate()
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
        timer = Timer.scheduledTimer(withTimeInterval: fastPollingInterval, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.resetToNormalPolling()
        }
    }
    
    private func resetToNormalPolling() {
        guard isMonitoring else { return }
        startAdaptivePolling()
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
    
    // MARK: - Notifications permission
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
    
    // MARK: - Battery update and alerts
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
        if levelDifference > 0.005 { return true } // tighter threshold
        if newBatteryInfo.isCharging != lastInfo.isCharging { return true }
        if newBatteryInfo.powerSource != lastInfo.powerSource { return true }
        let timeSinceLastUpdate = Date().timeIntervalSince(lastInfo.lastUpdateTime)
        return timeSinceLastUpdate > 10 // more frequent forced refresh
    }
    
    private func updatePollingIntervalIfNeeded(newBatteryInfo: BatteryInfo) {
        let currentInterval = timer?.timeInterval ?? fastPollingInterval
        let optimalInterval = getOptimalPollingInterval()
        if abs(currentInterval - optimalInterval) > 0.1 {
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
    
    // MARK: - Accurate battery info using IOKit only, normalized like system UI
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
            return lastBatteryInfo ?? BatteryInfo()
        }
        
        // Read capacity values
        let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int
        let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int
        let designCapacity = description[kIOPSDesignCapacityKey as String] as? Int
        
        // Power and charging flags
        let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String ?? "Unknown"
        let onAC = (powerSourceState == kIOPSACPowerValue)
        let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
        let isCharged = description[kIOPSIsChargedKey as String] as? Bool ?? false
        let isPresent = description["IsPresent"] as? Bool ?? true
        
        // Cycle count (robust, multi-source)
        let cycleCount = readCycleCount(fromDescription: description) ?? fetchCycleCountFromIORegistry() ?? lastBatteryInfo?.cycleCount
        
        // Compute percentage using IOKit only, matching system rounding
        var percent: Int
        if let cur = currentCapacity, let max = maxCapacity, max > 0 {
            percent = Int((Double(cur) / Double(max) * 100.0).rounded())
        } else if let cur = currentCapacity {
            percent = cur
        } else if let last = lastBatteryInfo?.systemPercentage {
            percent = last
        } else {
            percent = 100
        }
        
        // Normalize to system behavior while on AC
        if onAC {
            if isCharged {
                percent = 100
            } else if percent >= 99 {
                percent = 100
            }
        }
        
        // Clamp
        percent = max(0, min(100, percent))
        
        // Derive level exactly from the integer
        let batteryLevel = Float(percent) / 100.0
        
        // Charging status string
        let chargingStatus: String
        if !isPresent {
            chargingStatus = "No Battery"
        } else if isCharged {
            chargingStatus = "Charged"
        } else if isCharging {
            chargingStatus = "Charging"
        } else if onAC {
            chargingStatus = "Not Charging"
        } else if powerSourceState == kIOPSBatteryPowerValue {
            chargingStatus = "Discharging"
        } else {
            chargingStatus = "Unknown"
        }
        
        // Health percentage: MaxCapacity / DesignCapacity if both available; otherwise fallback
        let healthPercentage: Int = {
            if let max = maxCapacity, let design = designCapacity, design > 0 {
                return Int((Double(max) / Double(design) * 100.0).rounded())
            }
            // Fallback: if only max provided, treat as percentage-like but clamp 100
            if let max = maxCapacity {
                return min(max, 100)
            }
            return 100
        }()
        
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
        
        let info = BatteryInfo(
            level: batteryLevel,
            powerSource: formattedPowerSource,
            chargingStatus: chargingStatus,
            health: health,
            healthPercentage: healthPercentage,
            lastUpdateTime: Date(),
            systemPercentage: percent,
            cycleCount: cycleCount
        )
        
        return info
    }
    
    // MARK: - Cycle count from IOPS description (some systems expose it here)
    private func readCycleCount(fromDescription dict: [String: Any]) -> Int? {
        // Try common variants
        if let v = dict["Cycle Count"] as? Int { return v }
        if let v = dict["CycleCount"] as? Int { return v }
        if let v = dict["Cycle Count"] as? NSNumber { return v.intValue }
        if let v = dict["CycleCount"] as? NSNumber { return v.intValue }
        return nil
    }
    
    // MARK: - Cycle count via IORegistry (most reliable)
    private func fetchCycleCountFromIORegistry() -> Int? {
        // Try AppleSmartBattery first
        if let count = fetchCycleCount(serviceName: "AppleSmartBattery") {
            return count
        }
        // Some systems expose via AppleSmartBatteryManager
        if let count = fetchCycleCount(serviceName: "AppleSmartBatteryManager") {
            return count
        }
        return nil
    }
    
    private func fetchCycleCount(serviceName: String) -> Int? {
        guard let matching = IOServiceMatching(serviceName) else { return nil }
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        if result != KERN_SUCCESS { return nil }
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let cfValue = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                if let number = cfValue as? NSNumber {
                    return number.intValue
                } else if let intValue = cfValue as? Int {
                    return intValue
                }
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }
}

