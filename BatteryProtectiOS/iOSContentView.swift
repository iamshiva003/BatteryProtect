//
//  iOSContentView.swift
//  BatteryProtect
//
//  Created by Antigravity Agent on 2026-06-27.
//

#if os(iOS)
import SwiftUI

struct iOSContentView: View {
    @StateObject private var receiverService = CloudKitReceiverService.shared
    @StateObject private var localReceiverService = LocalNetworkReceiverService.shared
    @StateObject private var batteryService = iOSBatteryService.shared
    @State private var activeDevice: ActiveDeviceTab = .macbook
    @State private var isAnimating = false
    
    // Settings view states
    @State private var lowThreshold: Double = 20.0
    @State private var highThreshold: Double = 80.0
    
    enum ActiveDeviceTab {
        case macbook
        case iphone
    }
    
    var body: some View {
        ZStack {
            // Premium Dark Theme Background Gradient
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.08), Color(red: 0.01, green: 0.01, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
              .ignoresSafeArea()
            
            // Dynamic colorful glowing backing circles (Aesthetic micro-animations)
            ZStack {
                Circle()
                    .fill(glowColor.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(y: -100)
                    .scaleEffect(isAnimating ? 1.08 : 0.92)
                
                Circle()
                    .fill(Color(red: 0.98, green: 0.53, blue: 0.0).opacity(0.06))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: -80, y: 150)
                    .scaleEffect(isAnimating ? 0.95 : 1.05)
            }
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isAnimating)
            
            ScrollView {
                VStack(spacing: 28) {
                    
                    // Header Area
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                            Text("BatteryProtect")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Sleek Custom Tab Switcher
                        HStack(spacing: 4) {
                            DeviceTabButton(title: "MacBook", isActive: activeDevice == .macbook) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    activeDevice = .macbook
                                }
                            }
                            
                            DeviceTabButton(title: "iPhone", isActive: activeDevice == .iphone) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    activeDevice = .iphone
                                }
                            }
                        }
                        .padding(3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Main Content Render
                    if activeDevice == .macbook {
                        macbookSection
                    } else {
                        iphoneSection
                    }
                    
                    // Threshold & Notification Settings Card
                    settingsSection
                        .padding(.horizontal, 20)
                    
                    // Channel Sync Badges
                    connectionBadgesSection
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            isAnimating = true
            
            // Read local settings if saved, or set defaults
            lowThreshold = UserDefaults.standard.double(forKey: "lowBatteryThreshold")
            if lowThreshold == 0.0 { lowThreshold = 20.0 }
            highThreshold = UserDefaults.standard.double(forKey: "highBatteryThreshold")
            if highThreshold == 0.0 { highThreshold = 80.0 }
            
            // Enable sync capabilities on startup
            receiverService.enableCloudKitSync()
        }
    }
    
    // MARK: - MacBook View Section
    private var macbookSection: some View {
        VStack(spacing: 24) {
            if let macInfo = localReceiverService.macBatteryInfo {
                // Large circular progress gauge
                CircularBatteryGauge(info: macInfo)
                    .transition(.scale.combined(with: .opacity))
                
                // Detailed specs grid
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        DetailGridCard(
                            title: "Power Source",
                            value: macInfo.powerSource,
                            iconName: macInfo.isPluggedIn ? "powerplug.fill" : "battery.100",
                            iconColor: macInfo.isPluggedIn ? .green : .secondary
                        )
                        
                        DetailGridCard(
                            title: "Remaining Time",
                            value: formatTime(emptyMinutes: macInfo.timeToEmptyMinutes, fullMinutes: macInfo.timeToFullChargeMinutes, isCharging: macInfo.isCharging),
                            iconName: "clock.fill",
                            iconColor: .blue
                        )
                    }
                    
                    HStack(spacing: 12) {
                        DetailGridCard(
                            title: "Battery Cycles",
                            value: macInfo.cycleCount != nil ? "\(macInfo.cycleCount!) cycles" : "Unavailable",
                            iconName: "capsule.portrait.fill",
                            iconColor: .orange
                        )
                        
                        DetailGridCard(
                            title: "Battery Health",
                            value: "\(macInfo.health) (\(macInfo.healthPercentage)%)",
                            iconName: "heart.fill",
                            iconColor: .red
                        )
                    }
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Minimal Searching Loader (Mac app not active / connected)
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.04), lineWidth: 2)
                            .frame(width: 180, height: 180)
                        
                        Circle()
                            .stroke(Color.orange.opacity(0.15), lineWidth: 4)
                            .frame(width: 140, height: 140)
                            .scaleEffect(isAnimating ? 1.3 : 0.8)
                            .opacity(isAnimating ? 0.0 : 1.0)
                            .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: isAnimating)
                        
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 48))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                    .frame(height: 200)
                    
                    VStack(spacing: 6) {
                        Text("Searching for MacBook...")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Ensure the macOS BatteryProtect app is running and both devices are connected to the same Wi-Fi network.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .padding(.vertical, 10)
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - iPhone View Section
    private var iphoneSection: some View {
        VStack(spacing: 24) {
            let localInfo = BatteryInfo(
                level: batteryService.batteryLevel,
                powerSource: batteryService.powerSource,
                chargingStatus: batteryService.chargingStatus,
                health: "Excellent",
                healthPercentage: 99,
                lastUpdateTime: Date(),
                systemPercentage: batteryService.batteryPercentage,
                cycleCount: nil,
                timeToEmptyMinutes: nil,
                timeToFullChargeMinutes: nil
            )
            
            CircularBatteryGauge(info: localInfo)
                .transition(.scale.combined(with: .opacity))
            
            // iPhone Specs Grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    DetailGridCard(
                        title: "Power Source",
                        value: localInfo.powerSource,
                        iconName: localInfo.isPluggedIn ? "powerplug.fill" : "battery.100",
                        iconColor: localInfo.isPluggedIn ? .green : .secondary
                    )
                    
                    DetailGridCard(
                        title: "Charging Status",
                        value: localInfo.chargingStatus,
                        iconName: localInfo.isCharging ? "bolt.fill" : "arrow.down.forward.and.arrow.up.backward",
                        iconColor: localInfo.isCharging ? .green : .secondary
                    )
                }
                
                HStack(spacing: 12) {
                    DetailGridCard(
                        title: "Device Name",
                        value: UIDevice.current.name,
                        iconName: "iphone",
                        iconColor: .blue
                    )
                    
                    DetailGridCard(
                        title: "Battery Type",
                        value: "Internal Li-Ion",
                        iconName: "info.circle.fill",
                        iconColor: .orange
                    )
                }
            }
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - Settings View Card
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NOTIFICATIONS & THRESHOLDS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Thresholds display info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configured Alert Ranges")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("Alert pushes automatically to iOS on boundary breaches.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(lowThreshold))% — \(Int(highThreshold))%")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.orange)
                    .fontWeight(.bold)
            }
            
            // Custom slider controls
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Low Battery Alert Threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(lowThreshold))%")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    Slider(value: $lowThreshold, in: 10...35, step: 5) {
                        Text("Low Battery Threshold")
                    } minimumValueLabel: {
                        Text("10%").font(.caption2).foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("35%").font(.caption2).foregroundColor(.secondary)
                    }
                    .accentColor(.orange)
                    .onChange(of: lowThreshold) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "lowBatteryThreshold")
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("High Charge Alert Threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(highThreshold))%")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    Slider(value: $highThreshold, in: 70...95, step: 5) {
                        Text("High Battery Threshold")
                    } minimumValueLabel: {
                        Text("70%").font(.caption2).foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("95%").font(.caption2).foregroundColor(.secondary)
                    }
                    .accentColor(.green)
                    .onChange(of: highThreshold) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "highBatteryThreshold")
                    }
                }
            }
            .padding(.top, 4)
            
            // Request push access button
            if !receiverService.notificationPermissionGranted {
                Button(action: {
                    receiverService.requestNotificationPermission()
                }) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                        Text("Enable Screen Push Alerts")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Connection Sync Badges Panel
    private var connectionBadgesSection: some View {
        HStack(spacing: 12) {
            // Local WiFi Status Badge
            ConnectionBadge(
                title: "Local Wi-Fi Link",
                status: localReceiverService.connectionStatus.contains("Connected") ? "Connected" : "Scanning...",
                isActive: localReceiverService.connectionStatus.contains("Connected"),
                iconName: "wifi"
            )
            
            // iCloud Status Badge
            ConnectionBadge(
                title: "iCloud Sync Link",
                status: receiverService.icloudAccountStatus == "Available" ? "Active" : "Disabled",
                isActive: receiverService.icloudAccountStatus == "Available",
                iconName: "icloud.fill"
            )
        }
    }
    
    // MARK: - Helper Methods
    private var glowColor: Color {
        if activeDevice == .macbook, let macInfo = localReceiverService.macBatteryInfo {
            return macInfo.isCharging ? .green : (macInfo.level < 0.20 ? .red : .orange)
        } else if activeDevice == .iphone {
            return batteryService.isCharging ? .green : (batteryService.batteryLevel < 0.20 ? .red : .orange)
        }
        return .orange
    }
    
    private func formatTime(emptyMinutes: Int?, fullMinutes: Int?, isCharging: Bool) -> String {
        if isCharging, let mins = fullMinutes {
            let h = mins / 60
            let m = mins % 60
            return h > 0 ? "\(h)h \(m)m to full" : "\(m)m to full"
        } else if !isCharging, let mins = emptyMinutes {
            let h = mins / 60
            let m = mins % 60
            return h > 0 ? "\(h)h \(m)m left" : "\(m)m left"
        }
        return "Calculating..."
    }
}

// MARK: - Circular Battery Ring Gauge Widget
struct CircularBatteryGauge: View {
    let info: BatteryInfo
    let size: CGFloat = 190
    
    var body: some View {
        ZStack {
            // Track circle
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 14)
                .frame(width: size, height: size)
            
            // Colored progress stroke with gradient
            Circle()
                .trim(from: 0.0, to: CGFloat(info.level))
                .stroke(
                    LinearGradient(
                        colors: [gaugeColor, gaugeColor.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(Angle(degrees: -90))
                .shadow(color: gaugeColor.opacity(0.2), radius: 6, x: 0, y: 3)
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: info.level)
            
            // Text values inside circular gauge
            VStack(spacing: 2) {
                if info.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.4), radius: 6, y: 2)
                        .padding(.bottom, 2)
                } else {
                    Image(systemName: info.batteryIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                }
                
                Text("\(info.systemPercentage)%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(info.chargingStatus.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: size + 20)
    }
    
    private var gaugeColor: Color {
        if info.isCharging {
            return .green
        }
        let percent = info.level * 100.0
        if percent < 20.0 {
            return .red
        }
        return .orange
    }
}

// MARK: - Styled Device Switcher Segment Button
struct DeviceTabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(isActive ? .black : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isActive ? Color.orange : Color.clear)
                .cornerRadius(8)
        }
    }
}

// MARK: - Detail Info Grid Cards
struct DetailGridCard: View {
    let title: String
    let value: String
    let iconName: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Styled Connection Badges
struct ConnectionBadge: View {
    let title: String
    let status: String
    let isActive: Bool
    let iconName: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundColor(isActive ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(status)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            
            // Tiny status light
            Circle()
                .fill(isActive ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
                .shadow(color: (isActive ? Color.green : Color.orange).opacity(0.5), radius: 3)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
#endif
