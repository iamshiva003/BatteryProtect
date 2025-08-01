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
        VStack(spacing: 20) {
            Text("BatteryProtect")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                Text("Battery Level: \(Int(batteryLevel * 100))%")
                    .font(.title2)
                
                Text("Power Source: \(powerSource)")
                    .font(.title3)
                    .foregroundColor(powerSource.contains("AC") ? .green : .orange)
                
                Text("Status: \(chargingStatus)")
                    .font(.caption)
                    .foregroundColor(chargingStatus == "Charging" ? .green : 
                                   chargingStatus == "Charged" ? .blue : .orange)
                
                // Status info
                Text("Last Update: \(lastUpdateTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Text("Check menu bar for quick access")
                .font(.caption)
                .foregroundColor(.secondary)
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
        let isCharging = description?["IsCharging"] as? Bool ?? false
        let isCharged = description?["IsCharged"] as? Bool ?? false
        let isPresent = description?["IsPresent"] as? Bool ?? true
        
        // Determine charging status string
        let chargingStatus: String
        if !isPresent {
            chargingStatus = "No Battery"
        } else if isCharged {
            chargingStatus = "Charged"
        } else if isCharging {
            chargingStatus = "Charging"
        } else if powerSourceState == kIOPSACPowerValue {
            chargingStatus = "Not Charging"
        } else {
            chargingStatus = "Discharging"
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
