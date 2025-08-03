//
//  ContentView.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI
import IOKit.ps

struct ContentView: View {
    @State private var batteryLevel: Float = 1.0
    @State private var powerSource: String = "Unknown"
    @State private var chargingStatus: String = "Unknown"
    @State private var batteryHealth: String = "Unknown"
    @State private var batteryHealthPercentage: Int = 100
    @State private var lastUpdateTime: Date = Date()
    @State private var uiTimer: Timer?
    @State private var isAnimating: Bool = false
    @State private var isAppearing: Bool = false
    @State private var isHovering: Bool = false
    @State private var isHealthHovering: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    
    private var powerColor: Color {
        powerSource == "Power Adapter" ? .green : .orange
    }
    
    private var healthColor: Color {
        if batteryHealthPercentage >= 90 {
            return powerColor
        } else if batteryHealthPercentage >= 80 {
            return powerColor.opacity(0.8)
        } else if batteryHealthPercentage >= 60 {
            return powerColor.opacity(0.6)
        } else {
            return powerColor.opacity(0.4)
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private func getBatteryIcon() -> String {
        if batteryLevel <= 0.05 {
            return "battery.0.circle.fill"
        } else if batteryLevel <= 0.25 {
            return "battery.25.circle.fill"
        } else if batteryLevel <= 0.50 {
            return "battery.50.circle.fill"
        } else if batteryLevel <= 0.75 {
            return "battery.75.circle.fill"
        } else {
            return "battery.100.circle.fill"
        }
    }
    
    private func getBatteryColor() -> Color {
        if batteryLevel <= 0.15 {
            return .red
        } else if batteryLevel <= 0.25 {
            return .orange
        } else if powerSource == "Power Adapter" {
            return .green
        } else {
            return .orange
        }
    }
    
    private func getHealthIcon() -> String {
        if batteryHealthPercentage >= 90 {
            return "heart.fill"
        } else if batteryHealthPercentage >= 80 {
            return "heart"
        } else if batteryHealthPercentage >= 60 {
            return "heart.slash"
        } else {
            return "heart.slash.fill"
        }
    }
    
    private func getHealthTooltip() -> String {
        return "Battery health: \(batteryHealthPercentage)% of original capacity"
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                powerColor.opacity(colorScheme == .dark ? 0.1 : 0.05),
                backgroundColor
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // App Title
            HStack(spacing: 8) {
                Group {
                    if chargingStatus == "Charging" {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(powerColor)
                            .symbolEffect(.bounce, options: .repeating)
                            .scaleEffect(isHovering ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
                    } else {
                        Image(systemName: getBatteryIcon())
                            .font(.system(size: 24))
                            .foregroundStyle(getBatteryColor())
                            .scaleEffect(pulseScale)
                            .animation(
                                batteryLevel <= 0.15 ? 
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                                .spring(response: 0.3, dampingFraction: 0.6),
                                value: pulseScale
                            )
                    }
                }
                
                Text("Battery")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                + Text("Protect")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(powerColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundGradient)
                    .scaleEffect(isHovering ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
            }
            .offset(y: isAppearing ? 0 : -20)
            .opacity(isAppearing ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAppearing)
            
            // Battery Level Circle
            ZStack {
                // Background Circle
                Circle()
                    .stroke(backgroundColor, lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                // Progress Circle
                Circle()
                    .trim(from: 0, to: CGFloat(batteryLevel))
                    .stroke(
                        powerColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(dampingFraction: 0.7), value: batteryLevel)
                
                // Charging Animation
                if powerSource == "Power Adapter" && chargingStatus == "Charging" {
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(powerColor.opacity(0.3), lineWidth: 12)
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                
                // Battery Level Text
                VStack(spacing: 2) {
                    Text("\(Int(batteryLevel * 100))%")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(powerColor)
                        .animation(.spring(), value: batteryLevel)
                        .scaleEffect(batteryLevel <= 0.15 ? pulseScale : 1.0)
                    
                    Text(chargingStatus)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
                        .animation(.easeInOut, value: chargingStatus)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isAppearing ? 1 : 0.8)
            .opacity(isAppearing ? 1 : 0)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: isAppearing)
            
            // Status Pills Row
            HStack(spacing: 12) {
                // Power Source Pill
                HStack(spacing: 4) {
                    Image(systemName: powerSource == "Power Adapter" ? "poweroutlet.type.f" : "battery.100")
                        .font(.caption2)
                    Text(powerSource)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(powerColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
                        .scaleEffect(isHovering ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
                )
                .foregroundColor(powerColor)
                .animation(.easeInOut, value: powerSource)
                
                // Battery Health Pill
                HStack(spacing: 4) {
                    Image(systemName: getHealthIcon())
                        .font(.caption2)
                    Text("\(batteryHealthPercentage)%")
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(healthColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
                        .scaleEffect(isHealthHovering ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHealthHovering)
                )
                .foregroundColor(healthColor)
                .animation(.easeInOut, value: batteryHealthPercentage)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isHealthHovering = hovering
                    }
                }
                .help(getHealthTooltip())
            }
            .offset(y: isAppearing ? 0 : 20)
            .opacity(isAppearing ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: isAppearing)
            
            // Last Update (minimal)
            Text(lastUpdateTime.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4))
                .offset(y: isAppearing ? 0 : 20)
                .opacity(isAppearing ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: isAppearing)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 260)
        .onAppear {
            startUIUpdates()
            withAnimation {
                isAppearing = true
            }
        }
        .onDisappear {
            stopUIUpdates()
        }
    }
    
    private func startUIUpdates() {
        // Start charging animation if needed
        withAnimation {
            isAnimating = true
        }
        
        // Start pulse animation for low battery
        if batteryLevel <= 0.15 {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
        
        // Update UI immediately
        updateUI()
        
        // Set up timer for UI updates
        uiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateUI()
        }
    }
    
    private func stopUIUpdates() {
        withAnimation {
            isAnimating = false
            pulseScale = 1.0
        }
        uiTimer?.invalidate()
        uiTimer = nil
    }
    
    private func updateUI() {
        let (level, powerSource, chargingStatus, health, healthPercentage) = getBatteryInfo()
        
        DispatchQueue.main.async {
            // Update pulse animation based on battery level
            if level <= 0.15 && self.pulseScale == 1.0 {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    self.pulseScale = 1.1
                }
            } else if level > 0.15 && self.pulseScale != 1.0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    self.pulseScale = 1.0
                }
            }
            
            self.batteryLevel = level
            self.powerSource = powerSource
            self.chargingStatus = chargingStatus
            self.batteryHealth = health
            self.batteryHealthPercentage = healthPercentage
            self.lastUpdateTime = Date()
        }
    }
    
    private func getBatteryInfo() -> (level: Float, powerSource: String, chargingStatus: String, health: String, healthPercentage: Int) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources: NSArray = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue()
        
        guard let source = sources.firstObject else {
            return (1.0, "Unknown", "Unknown", "Unknown", 100)
        }
        
        let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef).takeUnretainedValue() as? [String: Any]
        

        
        // Get battery level
        var batteryLevel: Float = 1.0
        if let currentCapacity = description?[kIOPSCurrentCapacityKey as String] as? Int,
           let maxCapacity = description?[kIOPSMaxCapacityKey as String] as? Int,
           maxCapacity > 0 {
            batteryLevel = Float(currentCapacity) / Float(maxCapacity)
        }
        
        // Get power source state (matches native macOS indicator)
        let powerSourceState = description?[kIOPSPowerSourceStateKey as String] as? String ?? "Unknown"
        
        // Get charging status
        let isCharging = description?[kIOPSIsChargingKey as String] as? Bool ?? false
        let isCharged = description?[kIOPSIsChargedKey as String] as? Bool ?? false
        let isPresent = description?["IsPresent"] as? Bool ?? true
        
        // Determine charging status string to match system
        let chargingStatus: String
        if !isPresent {
            chargingStatus = "No Battery"
        } else if isCharged {
            chargingStatus = "Charged"
        } else if isCharging {
            chargingStatus = "Charging"
        } else if powerSourceState == kIOPSACPowerValue {
            chargingStatus = "Not Charging"
        } else if powerSourceState == kIOPSBatteryPowerValue {
            chargingStatus = "Discharging"
        } else {
            chargingStatus = "Unknown"
        }
        
        // Get battery health percentage
        let healthPercentage: Int
        if let maxCapacity = description?[kIOPSMaxCapacityKey as String] as? Int {
            // Use the maximum capacity as the health percentage
            healthPercentage = maxCapacity
        } else {
            healthPercentage = 100
        }
        
        // Get battery health description
        let health: String
        if healthPercentage >= 90 {
            health = "Excellent"
        } else if healthPercentage >= 80 {
            health = "Good"
        } else if healthPercentage >= 60 {
            health = "Fair"
        } else {
            health = "Poor"
        }
        
        // Format power source to match native macOS
        let formattedPowerSource: String
        switch powerSourceState {
        case kIOPSACPowerValue:
            formattedPowerSource = "Power Adapter"
        case kIOPSBatteryPowerValue:
            formattedPowerSource = "Battery"
        default:
            formattedPowerSource = powerSourceState
        }
        
        return (batteryLevel, formattedPowerSource, chargingStatus, health, healthPercentage)
    }
}

#Preview {
    ContentView()
}
