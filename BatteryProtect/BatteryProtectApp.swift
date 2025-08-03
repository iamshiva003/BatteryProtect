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
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusBarService: StatusBarService?
    private var batteryMonitor: BatteryMonitorService?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start performance monitoring
        PerformanceMonitor.shared.startMonitoring()
        
        // Initialize services
        batteryMonitor = BatteryMonitorService()
        statusBarService = StatusBarService(batteryMonitor: batteryMonitor!)
        
        // Start battery monitoring
        batteryMonitor?.startMonitoring()
        
        print("🚀 BatteryProtect started with optimizations:")
        print("   • Adaptive polling intervals")
        print("   • Memory-efficient caching")
        print("   • Reduced UI updates")
        print("   • Performance monitoring enabled")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop performance monitoring
        PerformanceMonitor.shared.stopMonitoring()
        
        // Cleanup services
        statusBarService?.cleanup()
        
        print("🛑 BatteryProtect shutting down...")
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Resume monitoring when app becomes active
        batteryMonitor?.startMonitoring()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Reduce monitoring when app is not active
        // Keep basic monitoring but reduce frequency
    }
}
