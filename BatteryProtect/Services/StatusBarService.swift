//
//  StatusBarService.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI
import AppKit
import Combine

class StatusBarService: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var batteryMonitor: BatteryMonitorService?
    private var statusBarTimer: Timer?
    private var lastIconUpdate: Date = Date.distantPast
    private var lastBatteryInfo: BatteryInfo?
    private var cancellable: AnyCancellable?
    
    // Keep a long fallback timer; primary updates come via Combine
    private let iconUpdateInterval: TimeInterval = 30.0
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
        setupImmediateUpdates()
    }
    
    deinit {
        print("🛑 StatusBarService deinit - cleaning up resources")
        cleanup()
    }
    
    private func setupStatusBar() {
        // Square status item for consistent image-only rendering
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        StatusBarService.sharedStatusItem = statusItem
        
        if let button = statusItem?.button {
            button.title = "" // image-only if we get a valid image
            button.toolTip = "Battery Protect"
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            // Allow proportional up or down scaling for a slightly larger symbol presentation
            button.imageScaling = .scaleProportionallyUpOrDown
            applyStatusButtonAppearance(for: BatteryInfo(), on: button) // initial placeholder
        }
        
        setupPopover()
        updateStatusBarIcon()
        startStatusBarTimer() // fallback only
    }
    
    private func setupImmediateUpdates() {
        // Update the icon immediately whenever batteryInfo publishes a change
        cancellable = batteryMonitor?.$batteryInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                guard let self, let button = self.statusItem?.button else { return }
                self.applyStatusButtonAppearance(for: info, on: button)
                self.lastBatteryInfo = info
                self.lastIconUpdate = Date()
            }
    }
    
    private func setupPopover() {
        guard popover == nil else { return }
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 320, height: 240)
        pop.behavior = .transient
        pop.animates = true
        pop.delegate = self
        pop.contentViewController = NSHostingController(rootView: ContentView())
        popover = pop
        setupGlobalEventMonitor()
    }
    
    private func setupGlobalEventMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalMouseClick(event: event)
        }
    }
    
    private func handleGlobalMouseClick(event: NSEvent) {
        guard let popover = popover, popover.isShown else { return }
        guard let contentViewController = popover.contentViewController,
              let popoverWindow = contentViewController.view.window else { return }
        let clickLocation = event.locationInWindow
        let popoverFrame = popoverWindow.frame
        if !popoverFrame.contains(clickLocation) {
            DispatchQueue.main.async { [weak self] in
                self?.popover?.performClose(nil)
            }
        }
    }
    
    private func startStatusBarTimer() {
        statusBarTimer?.invalidate()
        statusBarTimer = Timer.scheduledTimer(withTimeInterval: iconUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateStatusBarIcon()
        }
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(for: button)
            return
        }
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            if popover == nil { setupPopover() }
            if let popover = popover {
                button.window?.update()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        if let batteryMonitor = batteryMonitor {
            let info = batteryMonitor.batteryInfo
            let batteryTitle = NSMenuItem(title: "Battery: \(info.displayPercentage)%", action: nil, keyEquivalent: "")
            batteryTitle.isEnabled = false
            menu.addItem(batteryTitle)
            let powerSourceTitle = NSMenuItem(title: "Source: \(info.powerSource)", action: nil, keyEquivalent: "")
            powerSourceTitle.isEnabled = false
            menu.addItem(powerSourceTitle)
        } else {
            let batteryTitle = NSMenuItem(title: "Battery: Loading...", action: nil, keyEquivalent: "")
            batteryTitle.isEnabled = false
            menu.addItem(batteryTitle)
            let powerSourceTitle = NSMenuItem(title: "Source: Unknown", action: nil, keyEquivalent: "")
            powerSourceTitle.isEnabled = false
            menu.addItem(powerSourceTitle)
        }
        menu.addItem(NSMenuItem.separator())
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
        let openWindowItem = NSMenuItem(title: "Open in Window", action: #selector(openInWindowMode), keyEquivalent: "w")
        openWindowItem.target = self
        menu.addItem(openWindowItem)
        let settingsItem = NSMenuItem(title: "Battery Settings", action: #selector(openBatterySettings), keyEquivalent: "s")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit BatteryProtect", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
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
        if let existingWindow = StatusBarService.sharedWindowController?.window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if let existingController = StatusBarService.sharedWindowController {
            existingController.window?.close()
            StatusBarService.sharedWindowController = nil
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.title = "BatteryProtect"
        window.center()
        window.contentView = NSHostingView(rootView: ContentView())
        let controller = NSWindowController(window: window)
        StatusBarService.sharedWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func openBatterySettings() {
        DispatchQueue.main.async {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func quitApp() {
        DispatchQueue.main.async { [weak self] in
            self?.cleanup()
            NSApp.terminate(nil)
        }
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        let info = batteryMonitor?.batteryInfo ?? BatteryInfo()
        applyStatusButtonAppearance(for: info, on: button)
        lastIconUpdate = Date()
        lastBatteryInfo = info
    }
    
    private func applyStatusButtonAppearance(for info: BatteryInfo, on button: NSStatusBarButton) {
        if let image = statusBarImage(for: info) {
            button.image = image
            button.title = ""
            if info.level <= 0.20 {
                button.contentTintColor = NSColor.systemRed
            } else if info.level <= 0.50 {
                button.contentTintColor = NSColor.systemYellow
            } else if info.isPluggedIn {
                button.contentTintColor = NSColor.systemGreen
            } else {
                button.contentTintColor = nil
            }
        } else {
            button.image = nil
            button.title = info.isPluggedIn ? "🔌" : "🔋"
            button.contentTintColor = nil
        }
        button.toolTip = "Battery: \(info.displayPercentage)% - \(info.powerSource)"
    }
    
    private func statusBarImage(for info: BatteryInfo) -> NSImage? {
        let symbolBase: String = {
            switch info.level {
            case ..<0.05: return "battery.0"
            case ..<0.25: return "battery.25"
            case ..<0.50: return "battery.50"
            case ..<0.75: return "battery.75"
            default:       return "battery.100"
            }
        }()
        let preferredName = info.isPluggedIn ? "\(symbolBase).bolt" : symbolBase
        let fallbackName = info.isPluggedIn ? "bolt.fill" : "bolt.circle"
        // Increase the point size to make the icon larger in the menu bar
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        if let img = NSImage(systemSymbolName: preferredName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            img.isTemplate = true
            return img
        }
        if let img = NSImage(systemSymbolName: fallbackName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            img.isTemplate = true
            return img
        }
        return nil
    }
    
    func cleanup() {
        print("🧹 StatusBarService cleanup started")
        statusBarTimer?.invalidate()
        statusBarTimer = nil
        cancellable?.cancel()
        cancellable = nil
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let popover = popover {
            popover.performClose(nil)
            popover.delegate = nil
        }
        popover = nil
        StatusBarService.cleanupSharedWindow()
        batteryMonitor?.stopMonitoring()
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        StatusBarService.sharedStatusItem = nil
        print("✅ StatusBarService cleanup completed")
    }
    
    static func cleanupSharedWindow() {
        if let controller = sharedWindowController {
            controller.window?.close()
            sharedWindowController = nil
        }
    }
    
    static func handleForceQuit() {
        print("🛑 StatusBarService handling force quit")
        cleanupSharedWindow()
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
        return true
    }
}
