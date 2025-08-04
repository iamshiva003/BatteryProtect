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
    private var settingsWindowController: NSWindowController?
    
    deinit {
        print("🛑 AppDelegate deinit - cleaning up")
        cleanup()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the application menu
        setupApplicationMenu()
        
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
    
    private func setupApplicationMenu() {
        let mainMenu = NSMenu()
        
        // App Menu (BatteryProtect)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        
        appMenuItem.submenu = appMenu
        
        // About BatteryProtect
        let aboutItem = NSMenuItem(title: "About BatteryProtect", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Preferences/Settings
        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        appMenu.addItem(preferencesItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Services
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu()
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Hide BatteryProtect
        let hideItem = NSMenuItem(title: "Hide BatteryProtect", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)
        
        // Hide Others
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        // Show All
        let showAllItem = NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(showAllItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Quit BatteryProtect
        let quitItem = NSMenuItem(title: "Quit BatteryProtect", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        
        mainMenu.addItem(appMenuItem)
        
        // File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        
        let newWindowItem = NSMenuItem(title: "New Window", action: #selector(openNewWindow), keyEquivalent: "n")
        newWindowItem.target = self
        fileMenu.addItem(newWindowItem)
        
        fileMenu.addItem(NSMenuItem.separator())
        
        let closeItem = NSMenuItem(title: "Close Window", action: #selector(NSWindow.close), keyEquivalent: "w")
        fileMenu.addItem(closeItem)
        
        mainMenu.addItem(fileMenuItem)
        
        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        
        let minimizeItem = NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(minimizeItem)
        
        let zoomItem = NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(zoomItem)
        
        windowMenu.addItem(NSMenuItem.separator())
        
        let bringAllToFrontItem = NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenu.addItem(bringAllToFrontItem)
        
        mainMenu.addItem(windowMenuItem)
        
        // Help Menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        
        let helpItem = NSMenuItem(title: "BatteryProtect Help", action: #selector(showHelp), keyEquivalent: "?")
        helpItem.target = self
        helpMenu.addItem(helpItem)
        
        mainMenu.addItem(helpMenuItem)
        
        // Set the main menu
        NSApplication.shared.mainMenu = mainMenu
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About BatteryProtect"
        alert.informativeText = "BatteryProtect v1.0\n\nA macOS status bar application that monitors battery health and provides intelligent alerts to preserve battery longevity.\n\nCreated by Shivakumar Patil\n© 2025 All rights reserved."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func showPreferences() {
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        
        window.title = "BatteryProtect Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        
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
    
    @objc private func openNewWindow() {
        // Open app in window mode (same as status bar context menu)
        statusBarService?.openInWindowMode()
    }
    
    @objc private func showHelp() {
        // Open help documentation or show help dialog
        let alert = NSAlert()
        alert.messageText = "BatteryProtect Help"
        alert.informativeText = "BatteryProtect monitors your Mac's battery health and provides smart alerts.\n\n• Left-click the status bar icon to view battery information\n• Right-click for quick actions and settings\n• Alerts appear when battery is low (≤20%) or high (≥80%) while charging\n• Use Preferences to customize alert settings\n\nFor more information, visit the project documentation."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
        
        // Cleanup settings window
        settingsWindowController?.window?.close()
        settingsWindowController = nil
        
        batteryMonitor?.stopMonitoring()
        batteryMonitor = nil
        
        print("✅ AppDelegate cleanup completed")
    }
}

// MARK: - Preferences View
struct PreferencesView: View {
    @AppStorage("enableLowBatteryAlerts") private var enableLowBatteryAlerts = true
    @AppStorage("enableHighBatteryAlerts") private var enableHighBatteryAlerts = true
    @AppStorage("lowBatteryThreshold") private var lowBatteryThreshold = 20.0
    @AppStorage("highBatteryThreshold") private var highBatteryThreshold = 80.0
    @AppStorage("enablePerformanceMonitoring") private var enablePerformanceMonitoring = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "battery.100.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("BatteryProtect Preferences")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            
            // Alert Settings
            GroupBox("Alert Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Low Battery Alerts", isOn: $enableLowBatteryAlerts)
                    
                    if enableLowBatteryAlerts {
                        HStack {
                            Text("Low Battery Threshold:")
                            Slider(value: $lowBatteryThreshold, in: 5...50, step: 5)
                            Text("\(Int(lowBatteryThreshold))%")
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    
                    Toggle("Enable High Battery Alerts", isOn: $enableHighBatteryAlerts)
                    
                    if enableHighBatteryAlerts {
                        HStack {
                            Text("High Battery Threshold:")
                            Slider(value: $highBatteryThreshold, in: 60...95, step: 5)
                            Text("\(Int(highBatteryThreshold))%")
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                .padding()
            }
            
            // General Settings
            GroupBox("General Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Performance Monitoring", isOn: $enablePerformanceMonitoring)
                        .help("Monitor app performance and memory usage")
                    
                    Toggle("Start at Login", isOn: $startAtLogin)
                        .help("Automatically start BatteryProtect when you log in")
                        .onChange(of: startAtLogin) { newValue in
                            toggleStartAtLogin(enabled: newValue)
                        }
                }
                .padding()
            }
            
            // Info Section
            GroupBox("Information") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Version:")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text("Running")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Memory Usage:")
                        Spacer()
                        Text("\(String(format: "%.1f", Double(PerformanceMonitor.shared.getCurrentMemoryUsage()) / 1024.0 / 1024.0)) MB")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                
                Spacer()
                
                Button("Open System Battery Settings") {
                    openSystemBatterySettings()
                }
            }
            .padding(.bottom, 20)
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    private func resetToDefaults() {
        enableLowBatteryAlerts = true
        enableHighBatteryAlerts = true
        lowBatteryThreshold = 20.0
        highBatteryThreshold = 80.0
        enablePerformanceMonitoring = true
        startAtLogin = false
    }
    
    private func openSystemBatterySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func toggleStartAtLogin(enabled: Bool) {
        // Implementation for toggling start at login
        // This would require additional entitlements and implementation
        print("Start at login toggled: \(enabled)")
    }
}
