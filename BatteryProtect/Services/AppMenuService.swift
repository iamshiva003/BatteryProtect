//
//  AppMenuService.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import AppKit
import SwiftUI

protocol AppMenuServiceDelegate: AnyObject {
    func showAbout()
    func showPreferences()
    func openNewWindow()
    func showHelp()
    func openBatterySettings()
    func quitApp()
}

class AppMenuService: NSObject {
    weak var delegate: AppMenuServiceDelegate?
    
    func setupApplicationMenu() {
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
        delegate?.showAbout()
    }
    
    @objc private func showPreferences() {
        delegate?.showPreferences()
    }
    
    @objc private func openNewWindow() {
        delegate?.openNewWindow()
    }
    
    @objc private func showHelp() {
        delegate?.showHelp()
    }
} 