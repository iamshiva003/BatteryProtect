//
//  AppDelegateProtocol.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import Foundation
import AppKit

protocol AppDelegateProtocol: NSApplicationDelegate, ObservableObject {
    var statusBarService: StatusBarService? { get }
    var batteryMonitor: BatteryMonitorService? { get }
    
    func showAbout()
    func showPreferences()
    func openNewWindow()
    func showHelp()
    func openBatterySettings()
    func quitApp()
    func handleForceQuit()
} 