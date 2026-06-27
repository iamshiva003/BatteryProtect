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
        // Keep only a Settings scene. With LSUIElement=true, this won’t create any app menu or windows.
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
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = nil
        
        signalHandlerService.setupSignalHandlers()
        PerformanceMonitor.shared.startMonitoring()
        
        batteryMonitor = BatteryMonitorService()
        statusBarService = StatusBarService(batteryMonitor: batteryMonitor!)
        batteryMonitor?.startMonitoring()
        
        #if os(macOS)
        // Eagerly initialize local network notifications to start browsing immediately
        _ = LocalNetworkNotificationService.shared
        #endif
        
        print("🚀 BatteryProtect started with optimizations:")
        print("   • Adaptive polling intervals")
        print("   • Memory-efficient caching")
        print("   • Reduced UI updates")
        print("   • Performance monitoring enabled")
        print("   • Force quit support enabled")
        print("   • Application menu disabled (agent/app accessory)")
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
        batteryMonitor?.startMonitoring()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Reduce monitoring when app is not active if needed
    }
    
    private func cleanup() {
        PerformanceMonitor.shared.stopMonitoring()
        statusBarService?.cleanup()
        statusBarService = nil
        StatusBarService.cleanupSharedWindow()
        settingsWindowController?.window?.close()
        settingsWindowController = nil
        batteryMonitor?.stopMonitoring()
        batteryMonitor = nil
        print("✅ AppDelegate cleanup completed")
    }
}

// MARK: - AppMenuServiceDelegate
extension AppDelegate: AppMenuServiceDelegate {
    @objc func showAbout() {
        let alert = NSAlert()
        if let appIcon = NSImage(named: "AppIcon") {
            alert.icon = appIcon
        }
        alert.messageText = "About BatteryProtect"
        alert.informativeText = "BatteryProtect v1.0\n\nA macOS status bar application that monitors battery health and provides intelligent alerts to preserve battery longevity.\n\nCreated by Shivakumar Patil\n© 2025 All rights reserved."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func showPreferences() {
        // If already open, bring to front
        if let existingWindow = settingsWindowController?.window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Clean up any existing controller
        if let existingController = settingsWindowController {
            existingController.window?.close()
            settingsWindowController = nil
        }
        
        // Create a smaller, minimal window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.title = "Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        
        let preferencesView = PreferencesView()
        let hostingView = NSHostingView(rootView: preferencesView)
        window.contentView = hostingView
        
        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openNewWindow() {
        statusBarService?.openInWindowMode()
    }
    
    @objc func showHelp() {
        let alert = NSAlert()
        if let appIcon = NSImage(named: "AppIcon") {
            alert.icon = appIcon
        }
        alert.messageText = "BatteryProtect Help"
        alert.informativeText = "BatteryProtect monitors your Mac's battery health and provides smart alerts.\n\n• Left-click the status bar icon to view battery information\n• Right-click for quick actions and settings\n• Alerts appear when battery is low (≤20%) or high (≥80%) while charging\n• Use Preferences to customize alert settings"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func openBatterySettings() {
        DispatchQueue.main.async {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func quitApp() {
        DispatchQueue.main.async { [weak self] in
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

