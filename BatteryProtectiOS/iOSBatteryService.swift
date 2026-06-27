//
//  iOSBatteryService.swift
//  BatteryProtectiOS
//
//  Created by Antigravity Agent on 2026-06-27.
//

#if os(iOS)
import Foundation
import UIKit
import Combine

// MARK: - IOKit Dynamic Bindings for iOS
// IOKit is not publicly linked on iOS, but the framework exists at runtime.
// We dynamically load it to access the exact battery capacity readings.
private let kIOKitFrameworkPath = "/System/Library/Frameworks/IOKit.framework/IOKit"

private typealias IOServiceGetMatchingServiceFunc = @convention(c) (UInt32, CFDictionary) -> UInt32
private typealias IOServiceMatchingFunc = @convention(c) (UnsafePointer<CChar>) -> CFMutableDictionary?
private typealias IORegistryEntryCreateCFPropertyFunc = @convention(c) (UInt32, CFString, CFAllocator?, UInt32) -> Unmanaged<CFTypeRef>?
private typealias IOObjectReleaseFunc = @convention(c) (UInt32) -> kern_return_t

private func loadIOKitSymbol<T>(_ name: String) -> T? {
    guard let handle = dlopen(kIOKitFrameworkPath, RTLD_LAZY) else { return nil }
    guard let sym = dlsym(handle, name) else { return nil }
    return unsafeBitCast(sym, to: T.self)
}

/// Reads the precise battery percentage on iOS using IOKit's IORegistryEntry.
/// UIDevice.current.batteryLevel rounds to 5% increments on physical devices,
/// which does not match the status bar reading. This service reads the actual
/// system-reported current capacity via IOKit to compute the exact percentage.
class iOSBatteryService: ObservableObject {
    static let shared = iOSBatteryService()
    
    @Published var batteryPercentage: Int = 100
    @Published var batteryLevel: Float = 1.0
    @Published var chargingStatus: String = "Unknown"
    @Published var powerSource: String = "Battery"
    @Published var isCharging: Bool = false
    
    private var timer: Timer?
    
    // Dynamically loaded IOKit functions
    private let ioServiceGetMatchingService: IOServiceGetMatchingServiceFunc?
    private let ioServiceMatching: IOServiceMatchingFunc?
    private let ioRegistryEntryCreateCFProperty: IORegistryEntryCreateCFPropertyFunc?
    private let ioObjectRelease: IOObjectReleaseFunc?
    
    private init() {
        // Load IOKit symbols dynamically
        ioServiceGetMatchingService = loadIOKitSymbol("IOServiceGetMatchingService")
        ioServiceMatching = loadIOKitSymbol("IOServiceMatching")
        ioRegistryEntryCreateCFProperty = loadIOKitSymbol("IORegistryEntryCreateCFProperty")
        ioObjectRelease = loadIOKitSymbol("IOObjectRelease")
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        startPolling()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    /// Polls battery info every 15 seconds for smooth, real-time updates.
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        
        NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }
    
    /// Reads the exact battery percentage from the system.
    /// First tries IOKit registry (exact), falls back to UIDevice (5% granularity).
    func refresh() {
        let state = UIDevice.current.batteryState
        
        // Charging status from UIDevice (this is always accurate)
        switch state {
        case .charging:
            chargingStatus = "Charging"
            isCharging = true
            powerSource = "Power Adapter"
        case .full:
            chargingStatus = "Charged"
            isCharging = false
            powerSource = "Power Adapter"
        case .unplugged:
            chargingStatus = "Discharging"
            isCharging = false
            powerSource = "Battery"
        case .unknown:
            chargingStatus = "Unknown"
            isCharging = false
            powerSource = "Battery"
        @unknown default:
            chargingStatus = "Unknown"
            isCharging = false
            powerSource = "Battery"
        }
        
        // Try to get exact percentage from IOKit registry entry
        if let exactPercent = readExactBatteryPercentage() {
            batteryPercentage = exactPercent
            batteryLevel = Float(exactPercent) / 100.0
        } else {
            // Fallback to UIDevice
            let rawLevel = UIDevice.current.batteryLevel
            if rawLevel >= 0 {
                batteryPercentage = Int((rawLevel * 100).rounded())
                batteryLevel = rawLevel
            }
        }
    }
    
    /// Reads exact battery percentage via dynamically loaded IOKit on iOS.
    /// Returns nil if the IOKit functions are unavailable.
    private func readExactBatteryPercentage() -> Int? {
        guard let matching = ioServiceMatching,
              let getService = ioServiceGetMatchingService,
              let createProperty = ioRegistryEntryCreateCFProperty,
              let release = ioObjectRelease else {
            return nil
        }
        
        guard let matchDict = matching("IOPMPowerSource") else {
            return nil
        }
        
        // kIOMasterPortDefault = 0
        let service = getService(0, matchDict)
        guard service != 0 else {
            return nil
        }
        
        defer { _ = release(service) }
        
        var currentCapacity: Int?
        var maxCapacity: Int?
        
        if let prop = createProperty(service, "CurrentCapacity" as CFString, kCFAllocatorDefault, 0) {
            let value = prop.takeRetainedValue()
            currentCapacity = (value as? NSNumber)?.intValue
        }
        
        if let prop = createProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0) {
            let value = prop.takeRetainedValue()
            maxCapacity = (value as? NSNumber)?.intValue
        }
        
        if let current = currentCapacity, let max = maxCapacity, max > 0 {
            return min(100, (current * 100) / max)
        }
        
        return nil
    }
}
#endif
