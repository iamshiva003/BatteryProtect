//
//  StatusBarService.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI
import AppKit

class StatusBarService: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var batteryMonitor: BatteryMonitorService?
    private var statusBarTimer: Timer?
    private var lastIconUpdate: Date = Date.distantPast
    private var lastBatteryInfo: BatteryInfo?
    
    // Performance optimizations - optimized for faster response
    private let iconUpdateInterval: TimeInterval = 5.0 // Reduced from 10.0
    private var isPopoverShown = false
    
    // Window management - singleton approach
    private static var sharedWindowController: NSWindowController?
    
    // Static reference to status bar item for force quit cleanup
    private static var sharedStatusItem: NSStatusItem?
    
    // Global event monitor for detecting clicks outside popover
    private var globalMonitor: Any?
    
    init(batteryMonitor: BatteryMonitorService) {
        self.batteryMonitor = batteryMonitor
        super.init()
        setupStatusBar()
    }
    
    deinit {
        print("🛑 StatusBarService deinit - cleaning up resources")
        cleanup()
    }
    
    private func setupStatusBar() {
        // Create status bar item with proper length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Store static reference for force quit cleanup
        StatusBarService.sharedStatusItem = statusItem
        
        if let button = statusItem?.button {
            button.title = "🔋"
            button.toolTip = "Battery Protect"
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Ensure proper button sizing and positioning
            button.imagePosition = .imageLeft
            button.imageScaling = .scaleProportionallyDown
        }
        
        // Lazy load popover only when needed
        setupPopover()
        
        // Update status bar icon immediately
        updateStatusBarIcon()
        
        // Set up timer to update status bar icon with reduced frequency
        startStatusBarTimer()
    }
    
    private func setupPopover() {
        // Only create popover if it doesn't exist
        guard popover == nil else { return }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 240)
        popover?.behavior = .transient
        popover?.animates = true
        
        // Create content view controller
        let contentViewController = NSHostingController(rootView: ContentView())
        popover?.contentViewController = contentViewController
        
        // Add popover delegate to track visibility and handle outside clicks
        popover?.delegate = self
        
        // Set up global event monitor to detect clicks outside popover
        setupGlobalEventMonitor()
    }
    
    private func setupGlobalEventMonitor() {
        // Monitor mouse clicks globally to detect clicks outside the popover
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalMouseClick(event: event)
        }
    }
    
    private func handleGlobalMouseClick(event: NSEvent) {
        guard let popover = popover, popover.isShown else { return }
        
        // Get the popover window with proper null checking
        guard let contentViewController = popover.contentViewController,
              let popoverWindow = contentViewController.view.window else { return }
        
        // Get the click location and popover frame
        let clickLocation = event.locationInWindow
        let popoverFrame = popoverWindow.frame
        
        // Simple check: if click is not within the popover frame, close it
        if !popoverFrame.contains(clickLocation) {
            // Click is outside the popover, close it
            DispatchQueue.main.async { [weak self] in
                self?.popover?.performClose(nil)
            }
        }
    }
    
    private func startStatusBarTimer() {
        statusBarTimer = Timer.scheduledTimer(withTimeInterval: iconUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateStatusBarIcon()
        }
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        // Check if it's a right-click
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu(for: button)
            return
        }
        
        // Left click - toggle popover
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            // Ensure popover is created before showing
            if popover == nil {
                setupPopover()
            }
            
            if let popover = popover {
                // Ensure the button is properly positioned before showing popover
                button.window?.update()
                
                // Small delay to ensure proper status bar positioning
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Use standard popover positioning with proper menu bar alignment
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                    
                    // Activate the app to make the popover key and focused
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        
        // Battery Info Section - with safety checks
        if let batteryMonitor = batteryMonitor {
            let info = batteryMonitor.batteryInfo
            let batteryTitle = NSMenuItem(title: "Battery: \(info.displayPercentage)%", action: nil, keyEquivalent: "")
            batteryTitle.isEnabled = false
            menu.addItem(batteryTitle)
            
            let powerSourceTitle = NSMenuItem(title: "Source: \(info.powerSource)", action: nil, keyEquivalent: "")
            powerSourceTitle.isEnabled = false
            menu.addItem(powerSourceTitle)
        } else {
            // Fallback if batteryMonitor is nil
            let batteryTitle = NSMenuItem(title: "Battery: Loading...", action: nil, keyEquivalent: "")
            batteryTitle.isEnabled = false
            menu.addItem(batteryTitle)
            
            let powerSourceTitle = NSMenuItem(title: "Source: Unknown", action: nil, keyEquivalent: "")
            powerSourceTitle.isEnabled = false
            menu.addItem(powerSourceTitle)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // App actions (Preferences / About / Help)
        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferencesFromMenu), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        let aboutItem = NSMenuItem(title: "About BatteryProtect", action: #selector(showAboutFromMenu), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let helpItem = NSMenuItem(title: "BatteryProtect Help", action: #selector(showHelpFromMenu), keyEquivalent: "?")
        helpItem.target = self
        menu.addItem(helpItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Open in Window Mode
        let openWindowItem = NSMenuItem(title: "Open in Window", action: #selector(openInWindowMode), keyEquivalent: "w")
        openWindowItem.target = self
        menu.addItem(openWindowItem)
        
        // Open System Battery Settings
        let settingsItem = NSMenuItem(title: "Battery Settings", action: #selector(openBatterySettings), keyEquivalent: "s")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit App
        let quitItem = NSMenuItem(title: "Quit BatteryProtect", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Show the menu at the button's location with additional safety checks
        if let event = NSApp.currentEvent, button.window != nil {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        }
    }
    
    @objc private func openPreferencesFromMenu() {
        NSApp.sendAction(#selector(AppDelegate.showPreferences), to: nil, from: nil)
    }
    
    @objc private func showAboutFromMenu() {
        NSApp.sendAction(#selector(AppDelegate.showAbout), to: nil, from: nil)
    }
    
    @objc private func showHelpFromMenu() {
        NSApp.sendAction(#selector(AppDelegate.showHelp), to: nil, from: nil)
    }
    
    @objc func openInWindowMode() {
        // If window already exists and is visible, just bring it to front
        if let existingWindow = StatusBarService.sharedWindowController?.window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Clean up any existing window controller
        if let existingController = StatusBarService.sharedWindowController {
            existingController.window?.close()
            StatusBarService.sharedWindowController = nil
        }
        
        // Create a simple window without complex delegate management
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        
        window.title = "BatteryProtect"
        window.center()
        
        // Create a simple hosting view without complex lifecycle
        let hostingView = NSHostingView(rootView: ContentView())
        window.contentView = hostingView
        
        // Create window controller and store reference
        let controller = NSWindowController(window: window)
        StatusBarService.sharedWindowController = controller
        
        // Show window
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func openBatterySettings() {
        // Open system battery settings with safety check
        DispatchQueue.main.async {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func quitApp() {
        // Quit app with safety check and proper cleanup
        DispatchQueue.main.async { [weak self] in
            // Clean up before quitting
            self?.cleanup()
            NSApp.terminate(nil)
        }
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        let info = batteryMonitor?.batteryInfo ?? BatteryInfo()
        
        // Always update for power source changes, otherwise use smart updates
        let shouldUpdate = shouldUpdateIcon(batteryInfo: info) ||
                           info.powerSource != (lastBatteryInfo?.powerSource ?? "")
        
        if shouldUpdate {
            let isCharging = info.isPluggedIn
            
            // Update icon based on battery level and charging status
            let icon: String
            if isCharging {
                icon = "🔌"
            } else if info.level <= 0.2 {
                icon = "🔴"
            } else if info.level <= 0.5 {
                icon = "🟡"
            } else {
                icon = "🔋"
            }
            
            button.title = icon
            button.toolTip = "Battery: \(info.displayPercentage)% - \(info.powerSource)"
            
            lastIconUpdate = Date()
            lastBatteryInfo = info
        }
    }
    
    private func shouldUpdateIcon(batteryInfo: BatteryInfo) -> Bool {
        // Always update if no previous info
        guard let lastInfo = lastBatteryInfo else { return true }
        
        // Update if battery level changed significantly (3% or more - reduced from 5%)
        let levelDifference = abs(batteryInfo.level - lastInfo.level)
        if levelDifference > 0.03 {
            return true
        }
        
        // Update if charging status changed
        if batteryInfo.isCharging != lastInfo.isCharging {
            return true
        }
        
        // Update if power source changed
        if batteryInfo.powerSource != lastInfo.powerSource {
            return true
        }
        
        // Update every 15 seconds regardless (reduced from 30)
        let timeSinceLastUpdate = Date().timeIntervalSince(lastIconUpdate)
        return timeSinceLastUpdate > 15
    }
    
    func cleanup() {
        print("🧹 StatusBarService cleanup started")
        
        // Stop timer first
        statusBarTimer?.invalidate()
        statusBarTimer = nil
        
        // Remove global event monitor
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        // Close popover
        if let popover = popover {
            popover.performClose(nil)
            popover.delegate = nil
        }
        popover = nil
        
        // Clean up shared window controller
        StatusBarService.cleanupSharedWindow()
        
        // Stop battery monitoring
        batteryMonitor?.stopMonitoring()
        
        // Remove status bar item last
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        
        // Clear static reference
        StatusBarService.sharedStatusItem = nil
        
        print("✅ StatusBarService cleanup completed")
    }
    
    // Static method to cleanup shared window
    static func cleanupSharedWindow() {
        if let controller = sharedWindowController {
            controller.window?.close()
            sharedWindowController = nil
        }
    }
    
    // Static method to handle force quit scenarios
    static func handleForceQuit() {
        print("🛑 StatusBarService handling force quit")
        
        // Clean up shared window immediately
        cleanupSharedWindow()
        
        // Remove status bar item if it exists
        if let statusItem = sharedStatusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            sharedStatusItem = nil
        }
        
        print("✅ StatusBarService force quit cleanup completed")
    }
}

// MARK: - NSPopoverDelegate
extension StatusBarService: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        isPopoverShown = true
    }
    
    func popoverDidClose(_ notification: Notification) {
        isPopoverShown = false
    }
    
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        // Allow the popover to close when clicking outside
        return true
    }
}
