//
//  BatteryProtectApp.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI
import AppKit

@main
struct BatteryProtectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 350, height: 250)
        .commands {
            CommandGroup(replacing: .windowSize) { }
        }
        
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    private var batteryMonitor: BatteryMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "🔋"
            button.toolTip = "Battery Protect"
        }
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        // Start battery monitoring
        batteryMonitor = BatteryMonitor()
        batteryMonitor?.startMonitoring()
        
        // Disable maximize (zoom) and resizing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                window.styleMask.remove([.resizable, .fullScreen, .fullSizeContentView])
                window.standardWindowButton(.zoomButton)?.isEnabled = false
            }
        }
    }
    
    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        batteryMonitor?.stopMonitoring()
    }
}

class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Float = 1.0
    @Published var powerSource: String = "Unknown"
    @Published var chargingStatus: String = "Unknown"
    @Published var lastUpdateTime: Date = Date()

    private var timer: Timer?
    private var lastAlertTime: Date = Date.distantPast
    private var lastBatteryState: (level: Float, pluggedIn: Bool) = (1.0, false)
    
    func startMonitoring() {
        // Initial check
        updateBatteryStatus()
        
        // Set up timer for periodic checks
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateBatteryStatus()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateBatteryStatus() {
        let (level, powerSource, chargingStatus) = getBatteryInfo()
        let pluggedIn = (powerSource == "Power Adapter")
        checkBatteryAlerts(level: level, pluggedIn: pluggedIn)
        // Optionally update published properties here if needed
    }
    
    private func checkBatteryAlerts(level: Float, pluggedIn: Bool) {
        let now = Date()
        let timeSinceLastAlert = now.timeIntervalSince(lastAlertTime)
        
        // Check if battery state has changed significantly
        let powerSourceChanged = pluggedIn != lastBatteryState.pluggedIn
        
        // Show alert if:
        // 1. Battery is low (≤20%) and enough time has passed (30 seconds)
        // 2. Battery is high (≥80%) and plugged in and enough time has passed (30 seconds)
        // 3. Power source changed and conditions are met (immediate)
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
        
        // Update last battery state
        lastBatteryState = (level, pluggedIn)
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func getBatteryInfo() -> (level: Float, powerSource: String, chargingStatus: String) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources: NSArray = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue()
        
        guard let source = sources.firstObject else {
            return (1.0, "Unknown", "Unknown")
        }
        
        let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef).takeUnretainedValue() as? [String: Any]
        
        // Get battery level
        var batteryLevel: Float = 1.0
        if let currentCapacity = description?[kIOPSCurrentCapacityKey as String] as? Int,
           let maxCapacity = description?[kIOPSMaxCapacityKey as String] as? Int,
           maxCapacity > 0 {
            batteryLevel = Float(currentCapacity) / Float(maxCapacity)
        }
        
        // Get power source state (matches native macOS indicator)
        let powerSourceState = description?[kIOPSPowerSourceStateKey as String] as? String ?? "Unknown"
        let isPluggedIn = (powerSourceState == kIOPSACPowerValue)
        let powerSourceString = isPluggedIn ? "Power Adapter" : "Battery"
        
        // Get charging status for logging
        let isCharging = description?["IsCharging"] as? Bool ?? false
        let isCharged = description?["IsCharged"] as? Bool ?? false
        
        let chargingStatus: String
        if isCharged {
            chargingStatus = "Charged"
        } else if isCharging {
            chargingStatus = "Charging"
        } else if isPluggedIn {
            chargingStatus = "Not Charging"
        } else {
            chargingStatus = "Discharging"
        }
        
        return (batteryLevel, powerSourceString, chargingStatus)
    }
    
    private func updateUI() {
        let (level, powerSource, chargingStatus) = getBatteryInfo()
        DispatchQueue.main.async {
            self.batteryLevel = level
            self.powerSource = powerSource
            self.chargingStatus = chargingStatus
            self.lastUpdateTime = Date()
        }
    }
}
