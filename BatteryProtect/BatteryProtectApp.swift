//
//  BatteryProtectApp.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI
import AppKit
import Darwin

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
    
    deinit {
        print("🛑 AppDelegate deinit - cleaning up")
        cleanup()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up signal handlers for proper termination
        setupSignalHandlers()
        
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
        print("   • Force quit support enabled")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 BatteryProtect shutting down...")
        cleanup()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("🛑 Application termination requested")
        cleanup()
        return .terminateNow
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Resume monitoring when app becomes active
        batteryMonitor?.startMonitoring()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Reduce monitoring when app is not active
        // Keep basic monitoring but reduce frequency
    }
    
    private func setupSignalHandlers() {
        // Handle SIGTERM (normal termination)
        signal(SIGTERM) { _ in
            print("🛑 SIGTERM received - cleaning up")
            DispatchQueue.main.async {
                StatusBarService.handleForceQuit()
                NSApp.terminate(nil)
            }
        }
        
        // Handle SIGINT (Ctrl+C)
        signal(SIGINT) { _ in
            print("🛑 SIGINT received - cleaning up")
            DispatchQueue.main.async {
                StatusBarService.handleForceQuit()
                NSApp.terminate(nil)
            }
        }
        
        // Handle SIGQUIT (force quit)
        signal(SIGQUIT) { _ in
            print("🛑 SIGQUIT received - force quitting")
            DispatchQueue.main.async {
                StatusBarService.handleForceQuit()
                exit(0)
            }
        }
    }
    
    private func cleanup() {
        // Stop performance monitoring
        PerformanceMonitor.shared.stopMonitoring()
        
        // Cleanup services in correct order
        statusBarService?.cleanup()
        statusBarService = nil
        
        // Cleanup shared window
        StatusBarService.cleanupSharedWindow()
        
        batteryMonitor?.stopMonitoring()
        batteryMonitor = nil
        
        print("✅ AppDelegate cleanup completed")
    }
}
