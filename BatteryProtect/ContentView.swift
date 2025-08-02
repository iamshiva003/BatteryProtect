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
    @State private var lastUpdateTime: Date = Date()
    @State private var uiTimer: Timer?
    @State private var isAnimating: Bool = false
    
    private var powerColor: Color {
        powerSource == "Power Adapter" ? .green : .orange
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Battery Level Circle
            ZStack {
                // Background Circle
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: 12)
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
                    
                    Text(chargingStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .animation(.easeInOut, value: chargingStatus)
                }
            }
            
            // Power Source Pill
            Text(powerSource)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(powerColor.opacity(0.1))
                )
                .foregroundColor(powerColor)
                .animation(.easeInOut, value: powerSource)
            
            // Last Update (minimal)
            Text(lastUpdateTime.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding()
        .frame(minWidth: 300, minHeight: 220)
        .onAppear {
            startUIUpdates()
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
        }
        uiTimer?.invalidate()
        uiTimer = nil
    }
    
    private func updateUI() {
        let (level, powerSource, chargingStatus) = getBatteryInfo()
        
        DispatchQueue.main.async {
            self.batteryLevel = level
            self.powerSource = powerSource
            self.chargingStatus = chargingStatus
            self.lastUpdateTime = Date()
        }
    }
    
    private func getBatteryInfo() -> (level: Float, powerSource: String, chargingStatus: String) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources: NSArray = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue()
        
        guard let source = sources.firstObject else {
            return (1.0, "Unknown", "Unknown")
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
        
        return (batteryLevel, formattedPowerSource, chargingStatus)
    }
}

#Preview {
    ContentView()
}
