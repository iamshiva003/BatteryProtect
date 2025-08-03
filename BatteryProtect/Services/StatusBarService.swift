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
    private var batteryMonitor: BatteryMonitorService?
    private var statusBarTimer: Timer?
    private var lastIconUpdate: Date = Date.distantPast
    private var lastBatteryInfo: BatteryInfo?
    
    // Performance optimizations - optimized for faster response
    private let iconUpdateInterval: TimeInterval = 5.0 // Reduced from 10.0
    private var isPopoverShown = false
    
    init(batteryMonitor: BatteryMonitorService) {
        self.batteryMonitor = batteryMonitor
        super.init()
        setupStatusBar()
    }
    
    deinit {
        cleanup()
    }
    
    private func setupStatusBar() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "🔋"
            button.toolTip = "Battery Protect"
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Lazy load popover only when needed
        setupPopover()
        
        // Update status bar icon immediately
        updateStatusBarIcon()
        
        // Set up timer to update status bar icon with reduced frequency
        startStatusBarTimer()
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 350, height: 280)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        
        // Add popover delegate to track visibility and handle outside clicks
        popover?.delegate = self
        
        // Set up global event monitor to detect clicks outside popover
        setupGlobalEventMonitor()
    }
    
    private func setupGlobalEventMonitor() {
        // Monitor mouse clicks globally to detect clicks outside the popover
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalMouseClick(event: event)
        }
    }
    
    private func handleGlobalMouseClick(event: NSEvent) {
        guard let popover = popover, popover.isShown else { return }
        
        // Get the popover window
        guard let popoverWindow = popover.contentViewController?.view.window else { return }
        
        // Get the click location and popover frame
        let clickLocation = event.locationInWindow
        let popoverFrame = popoverWindow.frame
        
        // Simple check: if click is not within the popover frame, close it
        // We'll use the window coordinates directly since they should be in the same coordinate system
        if !popoverFrame.contains(clickLocation) {
            // Click is outside the popover, close it
            DispatchQueue.main.async {
                popover.performClose(nil)
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
        
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            // Ensure popover is created before showing
            if popover == nil {
                setupPopover()
            }
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        let batteryInfo = batteryMonitor?.batteryInfo ?? BatteryInfo()
        
        // Always update for power source changes, otherwise use smart updates
        let shouldUpdate = shouldUpdateIcon(batteryInfo: batteryInfo) || 
                          batteryInfo.powerSource != (lastBatteryInfo?.powerSource ?? "")
        
        if shouldUpdate {
            let isCharging = batteryInfo.isPluggedIn
            
            // Update icon based on battery level and charging status
            let icon: String
            if isCharging {
                icon = "🔌"
            } else if batteryInfo.level <= 0.2 {
                icon = "🔴"
            } else if batteryInfo.level <= 0.5 {
                icon = "🟡"
            } else {
                icon = "🔋"
            }
            
            button.title = icon
            button.toolTip = "Battery: \(Int(batteryInfo.level * 100))% - \(batteryInfo.powerSource)"
            
            lastIconUpdate = Date()
            lastBatteryInfo = batteryInfo
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
        statusBarTimer?.invalidate()
        statusBarTimer = nil
        
        popover?.performClose(nil)
        popover = nil
        
        batteryMonitor?.stopMonitoring()
        
        // Remove status bar item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
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