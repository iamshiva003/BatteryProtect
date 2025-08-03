//
//  StatusBarService.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI
import AppKit

class StatusBarService: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var batteryMonitor: BatteryMonitorService?
    
    init(batteryMonitor: BatteryMonitorService) {
        self.batteryMonitor = batteryMonitor
        setupStatusBar()
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
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 350, height: 280)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        
        // Update status bar icon based on battery level
        updateStatusBarIcon()
        
        // Set up timer to update status bar icon
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updateStatusBarIcon()
        }
    }
    
    @objc private func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        let batteryInfo = batteryMonitor?.batteryInfo ?? BatteryInfo()
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
    }
    
    func cleanup() {
        batteryMonitor?.stopMonitoring()
    }
} 