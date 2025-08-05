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
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("updateInterval") private var updateInterval = 30.0
    
    @StateObject private var batteryMonitor = BatteryMonitorService()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    // Logo (same as main app)
                    HStack(spacing: 8) {
                        Group {
                            if batteryMonitor.batteryInfo.isCharging {
                                Image(systemName: "bolt.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.green)
                                    .scaleEffect(1.0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: "bolt.circle.fill")
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: batteryMonitor.batteryInfo.batteryIcon)
                                    .font(.system(size: 32))
                                    .foregroundColor(Color.batteryColor(for: batteryMonitor.batteryInfo, colorScheme: colorScheme))
                                    .scaleEffect(1.0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: batteryMonitor.batteryInfo.batteryIcon)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: batteryMonitor.batteryInfo.isCharging)
                        
                        Text("Battery")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color.textColor(for: colorScheme))
                        + Text("Protect")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.batteryColor(for: batteryMonitor.batteryInfo, colorScheme: colorScheme))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.batteryColor(for: batteryMonitor.batteryInfo, colorScheme: colorScheme).opacity(colorScheme == .dark ? 0.35 : 0.12),
                                        Color.backgroundColor(for: colorScheme)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.batteryColor(for: batteryMonitor.batteryInfo, colorScheme: colorScheme).opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
                            )
                    )
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: batteryMonitor.batteryInfo.batteryIcon)
                    
                    Text("Preferences")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.textColor(for: colorScheme))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: "Preferences")
                    
                    Text("Customize your battery monitoring experience")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: "Customize your battery monitoring experience")
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Alert Settings
                SettingsSection(title: "Alert Settings", icon: "bell.fill") {
                    VStack(spacing: 16) {
                        // Low Battery Alerts
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Enable Low Battery Alerts", isOn: $enableLowBatteryAlerts)
                                .font(.system(size: 14, weight: .medium))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enableLowBatteryAlerts)
                            
                            if enableLowBatteryAlerts {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Low Battery Threshold:")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(lowBatteryThreshold))%")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 35, alignment: .trailing)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lowBatteryThreshold)
                                    }
                                    
                                    Slider(value: $lowBatteryThreshold, in: 5...50, step: 5)
                                        .accentColor(.orange)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lowBatteryThreshold)
                                }
                                .padding(.leading, 20)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                                    removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95))
                                ))
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: enableLowBatteryAlerts)
                            }
                        }
                        
                        Divider()
                        
                        // High Battery Alerts
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Enable High Battery Alerts", isOn: $enableHighBatteryAlerts)
                                .font(.system(size: 14, weight: .medium))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enableHighBatteryAlerts)
                            
                            if enableHighBatteryAlerts {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("High Battery Threshold:")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(highBatteryThreshold))%")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 35, alignment: .trailing)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: highBatteryThreshold)
                                    }
                                    
                                    Slider(value: $highBatteryThreshold, in: 60...95, step: 5)
                                        .accentColor(.green)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: highBatteryThreshold)
                                }
                                .padding(.leading, 20)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                                    removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95))
                                ))
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: enableHighBatteryAlerts)
                            }
                        }
                    }
                }
                
                // General Settings
                SettingsSection(title: "General Settings", icon: "gear") {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Enable Performance Monitoring", isOn: $enablePerformanceMonitoring)
                                .font(.system(size: 14, weight: .medium))
                                .help("Monitor app performance and memory usage")
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enablePerformanceMonitoring)
                        }
                        
                        Divider()
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enablePerformanceMonitoring)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Enable Notifications", isOn: $enableNotifications)
                                .font(.system(size: 14, weight: .medium))
                                .help("Show system notifications for battery alerts")
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enableNotifications)
                        }
                        
                        Divider()
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enableNotifications)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Start at Login", isOn: $startAtLogin)
                                .font(.system(size: 14, weight: .medium))
                                .help("Automatically start BatteryProtect when you log in")
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: startAtLogin)
                                .onChange(of: startAtLogin) { _, newValue in
                                    toggleStartAtLogin(enabled: newValue)
                                }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Update Interval:")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(updateInterval))s")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 35, alignment: .trailing)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: updateInterval)
                            }
                            
                            Slider(value: $updateInterval, in: 10...60, step: 5)
                                .accentColor(.blue)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: updateInterval)
                        }
                    }
                }
                
                // Information Section
                SettingsSection(title: "Information", icon: "info.circle.fill") {
                    VStack(spacing: 12) {
                        InfoRow(label: "Version", value: "1.0", color: .secondary)
                        InfoRow(label: "Status", value: "Running", color: .green)
                        InfoRow(label: "Memory Usage", value: "\(String(format: "%.1f", Double(PerformanceMonitor.shared.getCurrentMemoryUsage()) / 1024.0 / 1024.0)) MB", color: .secondary)
                        InfoRow(label: "Last Updated", value: Date().formatted(date: .abbreviated, time: .shortened), color: .secondary)
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                                            Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            resetToDefaults()
                        }
                    }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Reset to Defaults")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button(action: openSystemBatterySettings) {
                            HStack {
                                Image(systemName: "battery.100")
                                Text("System Settings")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    
                    Button(action: {
                        // Close preferences window
                        NSApp.sendAction(#selector(NSWindow.close), to: nil, from: nil)
                    }) {
                        Text("Close")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 540, height: 700)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            batteryMonitor.startMonitoring()
        }
        .onDisappear {
            batteryMonitor.stopMonitoring()
        }
    }
    
    private func resetToDefaults() {
        enableLowBatteryAlerts = true
        enableHighBatteryAlerts = true
        lowBatteryThreshold = 20.0
        highBatteryThreshold = 80.0
        enablePerformanceMonitoring = true
        startAtLogin = false
        enableNotifications = true
        updateInterval = 30.0
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

// MARK: - Supporting Views
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: icon)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
        )
        .scaleEffect(1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: title)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: label)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
        }
        .transition(.opacity.combined(with: .move(edge: .leading)))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
}
