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
    
    @State private var startAtLoginErrorMessage: String?

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
        }
    }

    private func resetToDefaults() {
        enableLowBatteryAlerts = true
        enableHighBatteryAlerts = true
        lowBatteryThreshold = 20.0
        highBatteryThreshold = 80.0
        startAtLogin = StartAtLoginManager.isEnabled() // keep in sync
        enableNotifications = true
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
}
