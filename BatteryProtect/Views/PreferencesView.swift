//
//  PreferencesView.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI
import AppKit

struct PreferencesView: View {
    // Stored settings
    @AppStorage("enableLowBatteryAlerts") private var enableLowBatteryAlerts = true
    @AppStorage("enableHighBatteryAlerts") private var enableHighBatteryAlerts = true
    @AppStorage("lowBatteryThreshold") private var lowBatteryThreshold = 20.0
    @AppStorage("highBatteryThreshold") private var highBatteryThreshold = 80.0
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enablePushToiPhone") private var enablePushToiPhone = false
    @AppStorage("enableLocalWiFiSync") private var enableLocalWiFiSync = true
    
    @State private var startAtLoginErrorMessage: String?
    @State private var hideSystemBattery = false
    @State private var showSandboxWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // General
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable notifications", isOn: $enableNotifications)

                    Toggle("Start at login", isOn: $startAtLogin)
                        .onChange(of: startAtLogin) { _, newValue in
                            toggleStartAtLogin(enabled: newValue)
                        }
                        .disabled(!StartAtLoginManager.isAvailable)
                    
                    if let message = startAtLoginErrorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Toggle("Hide macOS system battery icon", isOn: $hideSystemBattery)
                        .onChange(of: hideSystemBattery) { _, newValue in
                            let success = SystemBatteryManager.setSystemBatteryVisible(!newValue)
                            if !success {
                                showSandboxWarning = true
                            }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("General", systemImage: "gearshape")
                    .labelStyle(.titleAndIcon)
            }

            // Alerts
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Low battery alerts", isOn: $enableLowBatteryAlerts)

                    if enableLowBatteryAlerts {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow(alignment: .firstTextBaseline) {
                                Text("Low threshold")
                                    .foregroundStyle(.secondary)
                                Slider(value: $lowBatteryThreshold, in: 5...50, step: 5)
                                    .gridColumnAlignment(.leading)
                                    .tint(.orange)
                                Text("\(Int(lowBatteryThreshold))%")
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                        .gridCellUnsizedAxes([])
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    Toggle("High battery alerts", isOn: $enableHighBatteryAlerts)

                    if enableHighBatteryAlerts {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow(alignment: .firstTextBaseline) {
                                Text("High threshold")
                                    .foregroundStyle(.secondary)
                                Slider(value: $highBatteryThreshold, in: 60...95, step: 5)
                                    .gridColumnAlignment(.leading)
                                    .tint(.green)
                                Text("\(Int(highBatteryThreshold))%")
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                        .gridCellUnsizedAxes([])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Toggle("Send to iPhone (iCloud)", isOn: $enablePushToiPhone)
                            .padding(.leading, 16)
                        
                        Toggle("Send to iPhone (Local Wi-Fi)", isOn: $enableLocalWiFiSync)
                            .padding(.leading, 16)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Alerts", systemImage: "bell.fill")
                    .labelStyle(.titleAndIcon)
            }

            // Footer actions (no Close button)
            HStack {
                Button("Reset Defaults") {
                    resetToDefaults()
                }
                Spacer()
                Button("Battery Settings…") {
                    openSystemBatterySettings()
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 360) // compact width; height adapts to content
        .onAppear {
            // Sync the toggle to actual system status (source of truth)
            startAtLogin = StartAtLoginManager.isEnabled()
            hideSystemBattery = !SystemBatteryManager.isSystemBatteryVisible
        }
        .alert("System Settings Restricted", isPresented: $showSandboxWarning) {
            Button("Copy Terminal Command") {
                copyCommandsToClipboard(hide: hideSystemBattery)
            }
            Button("Cancel", role: .cancel) {
                hideSystemBattery = !hideSystemBattery
            }
        } message: {
            Text("App Sandbox restrictions prevent modifying system preferences directly.\n\nYou can copy and run the defaults command in Terminal to update the status bar.")
        }
    }

    private func resetToDefaults() {
        enableLowBatteryAlerts = true
        enableHighBatteryAlerts = true
        lowBatteryThreshold = 20.0
        highBatteryThreshold = 80.0
        startAtLogin = StartAtLoginManager.isEnabled() // keep in sync
        enableNotifications = true
        enablePushToiPhone = false
        enableLocalWiFiSync = true
    }

    private func openSystemBatterySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
            NSWorkspace.shared.open(url)
        }
    }

    private func toggleStartAtLogin(enabled: Bool) {
        startAtLoginErrorMessage = nil
        do {
            try StartAtLoginManager.setEnabled(enabled)
            // Reflect actual state after attempting to set it
            startAtLogin = StartAtLoginManager.isEnabled()
        } catch {
            // Revert toggle and show error
            startAtLogin = StartAtLoginManager.isEnabled()
            startAtLoginErrorMessage = error.localizedDescription
            print("Start at Login error: \(error)")
        }
    }

    private func copyCommandsToClipboard(hide: Bool) {
        let command = hide 
            ? "defaults write com.apple.controlcenter \"NSStatusItem Visible Battery\" -bool false && killall ControlCenter"
            : "defaults write com.apple.controlcenter \"NSStatusItem Visible Battery\" -bool true && killall ControlCenter"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
    }
}

struct SystemBatteryManager {
    static var isSystemBatteryVisible: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.controlcenter", "NSStatusItem Visible Battery"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output == "1" || output.lowercased() == "true"
            }
        } catch {
            print("Failed to read system battery visibility: \(error)")
        }
        return true // default fallback
    }
    
    @discardableResult
    static func setSystemBatteryVisible(_ visible: Bool) -> Bool {
        let defaultsProcess = Process()
        defaultsProcess.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defaultsProcess.arguments = ["write", "com.apple.controlcenter", "NSStatusItem Visible Battery", "-bool", visible ? "true" : "false"]
        
        do {
            try defaultsProcess.run()
            defaultsProcess.waitUntilExit()
            if defaultsProcess.terminationStatus != 0 {
                return false
            }
            
            // Reload ControlCenter
            let killProcess = Process()
            killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killProcess.arguments = ["ControlCenter"]
            try killProcess.run()
            killProcess.waitUntilExit()
            return killProcess.terminationStatus == 0
        } catch {
            print("Failed to set system battery visibility or reload ControlCenter: \(error)")
            return false
        }
    }
}
