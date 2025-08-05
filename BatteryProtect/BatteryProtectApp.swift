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

class AppDelegate: NSObject, AppDelegateProtocol {
    var statusBarService: StatusBarService?
    var batteryMonitor: BatteryMonitorService?
    private var settingsWindowController: NSWindowController?
    private var appMenuService: AppMenuService
    private var signalHandlerService: SignalHandlerService
    
    override init() {
        self.appMenuService = AppMenuService()
        self.signalHandlerService = SignalHandlerService()
        super.init()
        
        // Set up delegates
        self.appMenuService.delegate = self
        self.signalHandlerService.delegate = self
    }
    
    deinit {
        print("🛑 AppDelegate deinit - cleaning up")
        cleanup()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the application menu
        appMenuService.setupApplicationMenu()
        
        // Set up signal handlers for proper termination
        signalHandlerService.setupSignalHandlers()
        
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
        print("   • Application menu with settings enabled")
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
    

    

    

    
    private func cleanup() {
        // Stop performance monitoring
        PerformanceMonitor.shared.stopMonitoring()
        
        // Cleanup services in correct order
        statusBarService?.cleanup()
        statusBarService = nil
        
        // Cleanup shared window
        StatusBarService.cleanupSharedWindow()
        
        // Cleanup settings window
        settingsWindowController?.window?.close()
        settingsWindowController = nil
        
        batteryMonitor?.stopMonitoring()
        batteryMonitor = nil
        
        print("✅ AppDelegate cleanup completed")
    }
}

// MARK: - AppMenuServiceDelegate
extension AppDelegate: AppMenuServiceDelegate {
    func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About BatteryProtect"
        alert.informativeText = "BatteryProtect v1.0\n\nA macOS status bar application that monitors battery health and provides intelligent alerts to preserve battery longevity.\n\nCreated by Shivakumar Patil\n© 2025 All rights reserved."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func showPreferences() {
        // Close existing preferences window if open
        if let existingWindow = settingsWindowController?.window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Clean up any existing window controller
        if let existingController = settingsWindowController {
            existingController.window?.close()
            settingsWindowController = nil
        }
        
        // Create preferences window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 700),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        
        window.title = "BatteryProtect Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 540, height: 700))
        
        // Create preferences view
        let preferencesView = PreferencesView()
        let hostingView = NSHostingView(rootView: preferencesView)
        window.contentView = hostingView
        
        // Create window controller
        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        
        // Show window
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openNewWindow() {
        // Open app in window mode (same as status bar context menu)
        statusBarService?.openInWindowMode()
    }
    
    func showHelp() {
        // Open help documentation or show help dialog
        let alert = NSAlert()
        alert.messageText = "BatteryProtect Help"
        alert.informativeText = "BatteryProtect monitors your Mac's battery health and provides smart alerts.\n\n• Left-click the status bar icon to view battery information\n• Right-click for quick actions and settings\n• Alerts appear when battery is low (≤20%) or high (≥80%) while charging\n• Use Preferences to customize alert settings\n\nFor more information, visit the project documentation."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func openBatterySettings() {
        // Open system battery settings with safety check
        DispatchQueue.main.async { [weak self] in
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func quitApp() {
        // Quit app with safety check and proper cleanup
        DispatchQueue.main.async { [weak self] in
            // Clean up before quitting
            self?.cleanup()
            NSApp.terminate(nil)
        }
    }
}

// MARK: - SignalHandlerServiceDelegate
extension AppDelegate: SignalHandlerServiceDelegate {
    func handleForceQuit() {
        print("🛑 AppDelegate handling force quit")
        StatusBarService.handleForceQuit()
    }
}


