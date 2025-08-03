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
        // Initialize services
        batteryMonitor = BatteryMonitorService()
        statusBarService = StatusBarService(batteryMonitor: batteryMonitor!)
        
        // Start battery monitoring
        batteryMonitor?.startMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusBarService?.cleanup()
    }
}
