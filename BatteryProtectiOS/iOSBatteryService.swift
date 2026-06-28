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

/// Reads the precise battery percentage on iOS using libMobileGestalt.
/// UIDevice.current.batteryLevel rounds to 5% increments on many physical devices.
/// libMobileGestalt provides the exact percentage (same as status bar).
class iOSBatteryService: ObservableObject {
    static let shared = iOSBatteryService()
    
    @Published var batteryPercentage: Int = 100
    @Published var batteryLevel: Float = 1.0
    @Published var chargingStatus: String = "Unknown"
    @Published var powerSource: String = "Battery"
    @Published var isCharging: Bool = false
    
    private var timer: Timer?
    private var mgCopyAnswer: MGCopyAnswerFunc?
    private var gestaltAvailable: Bool = false
    private var loggedSource: Bool = false
    
    // libMobileGestalt function signature
    private typealias MGCopyAnswerFunc = @convention(c) (CFString) -> Unmanaged<CFTypeRef>?
    
    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        loadMobileGestalt()
        refresh()
        startPolling()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - libMobileGestalt Dynamic Loading
    
    private func loadMobileGestalt() {
        guard let handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY) else {
            print("iOSBatteryService: Could not load libMobileGestalt.")
            return
        }
        
        if let sym = dlsym(handle, "MGCopyAnswer") {
            mgCopyAnswer = unsafeBitCast(sym, to: MGCopyAnswerFunc.self)
            gestaltAvailable = true
            print("iOSBatteryService: libMobileGestalt loaded successfully.")
        } else {
            print("iOSBatteryService: Could not find MGCopyAnswer symbol.")
        }
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
        
        // Try libMobileGestalt for exact reading, fall back to UIDevice
        if gestaltAvailable, let exactPercent = readGestaltBatteryPercentage() {
            if !loggedSource {
                print("iOSBatteryService: Using libMobileGestalt exact percentage: \(exactPercent)%")
                loggedSource = true
            }
            batteryPercentage = exactPercent
            batteryLevel = Float(exactPercent) / 100.0
        } else {
            let rawLevel = UIDevice.current.batteryLevel
            if rawLevel >= 0 {
                let percent = Int((Double(rawLevel) * 100.0).rounded())
                if !loggedSource {
                    print("iOSBatteryService: Falling back to UIDevice.batteryLevel: \(rawLevel) → \(percent)%")
                    loggedSource = true
                }
                batteryPercentage = percent
                batteryLevel = rawLevel
            }
        }
    }
    
    // MARK: - libMobileGestalt Battery Reading
    
    /// Reads the exact battery percentage from libMobileGestalt.
    /// MGCopyAnswer("BatteryCurrentCapacity") returns the exact integer percentage (0-100).
    private func readGestaltBatteryPercentage() -> Int? {
        guard let mgCopy = mgCopyAnswer else { return nil }
        
        // "BatteryCurrentCapacity" returns an integer 0-100 (exact, same as status bar)
        if let result = mgCopy("BatteryCurrentCapacity" as CFString) {
            let value = result.takeRetainedValue()
            if let number = value as? NSNumber {
                let percent = number.intValue
                if percent >= 0 && percent <= 100 {
                    return percent
                }
            }
        }
        
        return nil
    }
}
#endif
