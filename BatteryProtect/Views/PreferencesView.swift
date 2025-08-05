//
//  PreferencesView.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI

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