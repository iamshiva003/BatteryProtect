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
    
    var body: some View {
        VStack(spacing: 24) {
            // Battery Level Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: CGFloat(batteryLevel))
                    .stroke(
                        powerSource == "Power Adapter" ? Color.green : Color.orange,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(Int(batteryLevel * 100))%")
                        .font(.system(size: 28, weight: .medium))
                    Text(chargingStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
            
            // Power Source Badge
            Text(powerSource)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                )
                .foregroundColor(powerSource == "Power Adapter" ? .green : .primary)
            
            // Last Update
            Text(lastUpdateTime.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, -8)
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
        // Update UI immediately
        updateUI()
        
        // Set up timer for UI updates
        uiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateUI()
        }
    }
    
    private func stopUIUpdates() {
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
