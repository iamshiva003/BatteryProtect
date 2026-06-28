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

/// Reads the precise battery percentage on iOS by dynamically loading IOKit.
/// UIDevice.current.batteryLevel rounds to 5% increments on many physical devices.
/// This service reads CurrentCapacity/MaxCapacity from the IOKit registry
/// (the same data source the status bar uses) for 1% accuracy.
class iOSBatteryService: ObservableObject {
    static let shared = iOSBatteryService()
    
    @Published var batteryPercentage: Int = 100
    @Published var batteryLevel: Float = 1.0
    @Published var chargingStatus: String = "Unknown"
    @Published var powerSource: String = "Battery"
    @Published var isCharging: Bool = false
    
    private var timer: Timer?
    private var ioKitHandle: UnsafeMutableRawPointer?
    private var ioKitAvailable: Bool = false
    private var ioKitReadSucceeded: Bool = false
    
    // Dynamically resolved IOKit function pointers
    private var _IOServiceGetMatchingService: (@convention(c) (UInt32, CFDictionary) -> UInt32)?
    private var _IOServiceMatching: (@convention(c) (UnsafePointer<CChar>) -> CFMutableDictionary?)?
    private var _IORegistryEntryCreateCFProperty: (@convention(c) (UInt32, CFString, CFAllocator?, UInt32) -> Unmanaged<CFTypeRef>?)?
    private var _IORegistryEntryCreateCFProperties: (@convention(c) (UInt32, UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, CFAllocator?, UInt32) -> kern_return_t)?
    private var _IOObjectRelease: (@convention(c) (UInt32) -> kern_return_t)?
    
    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        loadIOKit()
        refresh()
        startPolling()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - IOKit Dynamic Loading
    
    private func loadIOKit() {
        let paths = [
            "/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit",
            "/System/Library/Frameworks/IOKit.framework/IOKit"
        ]
        
        for path in paths {
            if let handle = dlopen(path, RTLD_LAZY) {
                ioKitHandle = handle
                break
            }
        }
        
        guard let handle = ioKitHandle else {
            print("iOSBatteryService: Could not dlopen IOKit. Will use UIDevice fallback.")
            ioKitAvailable = false
            return
        }
        
        if let sym = dlsym(handle, "IOServiceGetMatchingService") {
            _IOServiceGetMatchingService = unsafeBitCast(sym, to: (@convention(c) (UInt32, CFDictionary) -> UInt32).self)
        }
        if let sym = dlsym(handle, "IOServiceMatching") {
            _IOServiceMatching = unsafeBitCast(sym, to: (@convention(c) (UnsafePointer<CChar>) -> CFMutableDictionary?).self)
        }
        if let sym = dlsym(handle, "IORegistryEntryCreateCFProperty") {
            _IORegistryEntryCreateCFProperty = unsafeBitCast(sym, to: (@convention(c) (UInt32, CFString, CFAllocator?, UInt32) -> Unmanaged<CFTypeRef>?).self)
        }
        if let sym = dlsym(handle, "IORegistryEntryCreateCFProperties") {
            _IORegistryEntryCreateCFProperties = unsafeBitCast(sym, to: (@convention(c) (UInt32, UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, CFAllocator?, UInt32) -> kern_return_t).self)
        }
        if let sym = dlsym(handle, "IOObjectRelease") {
            _IOObjectRelease = unsafeBitCast(sym, to: (@convention(c) (UInt32) -> kern_return_t).self)
        }
        
        ioKitAvailable = (_IOServiceGetMatchingService != nil &&
                          _IOServiceMatching != nil &&
                          _IORegistryEntryCreateCFProperty != nil &&
                          _IOObjectRelease != nil)
        
        print("iOSBatteryService: IOKit loaded = \(ioKitAvailable)")
    }
    
    // MARK: - Polling
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        
        NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }
    
    // MARK: - Refresh
    
    func refresh() {
        let state = UIDevice.current.batteryState
        
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
        
        // Try IOKit first for exact reading, fall back to UIDevice
        if ioKitAvailable, let exactPercent = readIOKitBatteryPercentage() {
            if !ioKitReadSucceeded {
                print("iOSBatteryService: IOKit battery read SUCCEEDED. Using exact percentage.")
                ioKitReadSucceeded = true
            }
            batteryPercentage = exactPercent
            batteryLevel = Float(exactPercent) / 100.0
        } else {
            if ioKitAvailable && !ioKitReadSucceeded {
                print("iOSBatteryService: IOKit read returned nil. Falling back to UIDevice.")
            }
            let rawLevel = UIDevice.current.batteryLevel
            if rawLevel >= 0 {
                batteryPercentage = Int((rawLevel * 100).rounded())
                batteryLevel = rawLevel
            }
        }
    }
    
    // MARK: - IOKit Battery Reading
    
    /// Tries multiple IOKit service names and property combinations.
    private func readIOKitBatteryPercentage() -> Int? {
        let serviceNames = ["IOPMPowerSource", "AppleSmartBattery", "charger"]
        
        for serviceName in serviceNames {
            if let percent = readCapacityFromService(named: serviceName) {
                return percent
            }
        }
        
        // If individual property reads failed, try dumping all properties
        // to discover what keys are available on this device
        if !ioKitReadSucceeded {
            dumpServiceProperties()
        }
        
        return nil
    }
    
    /// Reads battery percentage from a named IOKit service.
    /// Tries multiple property name combinations used across iOS versions.
    private func readCapacityFromService(named serviceName: String) -> Int? {
        guard let matching = _IOServiceMatching,
              let getService = _IOServiceGetMatchingService,
              let createProperty = _IORegistryEntryCreateCFProperty,
              let release = _IOObjectRelease else {
            return nil
        }
        
        guard let matchDict = matching(serviceName) else { return nil }
        
        let service = getService(0, matchDict)
        guard service != 0 else { return nil }
        
        defer { _ = release(service) }
        
        // Try multiple property name combinations used on different iOS hardware
        let capacityPairs: [(current: String, max: String)] = [
            ("CurrentCapacity", "MaxCapacity"),
            ("AppleRawCurrentCapacity", "AppleRawMaxCapacity"),
            ("BatteryCurrentCapacity", "BatteryMaxCapacity")
        ]
        
        for pair in capacityPairs {
            var currentCapacity: Int?
            var maxCapacity: Int?
            
            if let prop = createProperty(service, pair.current as CFString, kCFAllocatorDefault, 0) {
                currentCapacity = (prop.takeRetainedValue() as? NSNumber)?.intValue
            }
            
            if let prop = createProperty(service, pair.max as CFString, kCFAllocatorDefault, 0) {
                maxCapacity = (prop.takeRetainedValue() as? NSNumber)?.intValue
            }
            
            if let current = currentCapacity, let maxCap = maxCapacity, maxCap > 0 {
                let percent: Int
                if maxCap <= 100 {
                    // MaxCapacity is already percentage-based (0-100 scale)
                    percent = current
                } else {
                    // MaxCapacity is raw mAh — compute percentage
                    percent = Int((Double(current) / Double(maxCap) * 100.0).rounded())
                }
                let clamped = Swift.max(0, Swift.min(100, percent))
                if !ioKitReadSucceeded {
                    print("iOSBatteryService: Read from '\(serviceName)' using '\(pair.current)/\(pair.max)': \(current)/\(maxCap) = \(clamped)%")
                }
                return clamped
            }
        }
        
        return nil
    }
    
    /// Dumps all available IOKit properties for battery services (called once for debugging).
    private func dumpServiceProperties() {
        guard let matching = _IOServiceMatching,
              let getService = _IOServiceGetMatchingService,
              let createProperties = _IORegistryEntryCreateCFProperties,
              let release = _IOObjectRelease else {
            print("iOSBatteryService: Cannot dump properties — missing IOKit functions.")
            return
        }
        
        let serviceNames = ["IOPMPowerSource", "AppleSmartBattery", "charger"]
        
        for serviceName in serviceNames {
            guard let matchDict = matching(serviceName) else { continue }
            let service = getService(0, matchDict)
            guard service != 0 else {
                print("iOSBatteryService: Service '\(serviceName)' not found.")
                continue
            }
            
            defer { _ = release(service) }
            
            var propertiesRef: Unmanaged<CFMutableDictionary>?
            let result = createProperties(service, &propertiesRef, kCFAllocatorDefault, 0)
            
            if result == 0, let props = propertiesRef?.takeRetainedValue() as? [String: Any] {
                let keys = props.keys.sorted()
                print("iOSBatteryService: [\(serviceName)] Available keys (\(keys.count)): \(keys)")
                
                // Print capacity-related values
                for key in keys where key.lowercased().contains("capacity") || key.lowercased().contains("battery") || key.lowercased().contains("current") || key.lowercased().contains("percent") {
                    print("iOSBatteryService: [\(serviceName)] \(key) = \(props[key] ?? "nil")")
                }
            } else {
                print("iOSBatteryService: [\(serviceName)] Could not read properties (result=\(result)).")
            }
        }
    }
}
#endif
