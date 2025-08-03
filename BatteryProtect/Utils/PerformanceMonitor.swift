//
//  PerformanceMonitor.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import Foundation
import Darwin

class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private var memoryUsageTimer: Timer?
    private var lastMemoryUsage: UInt64 = 0
    private var peakMemoryUsage: UInt64 = 0
    
    private init() {}
    
    func startMonitoring() {
        // Monitor memory usage every 30 seconds
        memoryUsageTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.logMemoryUsage()
        }
        
        // Log initial memory usage
        logMemoryUsage()
    }
    
    func stopMonitoring() {
        memoryUsageTimer?.invalidate()
        memoryUsageTimer = nil
    }
    
    private func logMemoryUsage() {
        let currentMemory = getMemoryUsage()
        let memoryInMB = Double(currentMemory) / 1024.0 / 1024.0
        
        if currentMemory > peakMemoryUsage {
            peakMemoryUsage = currentMemory
        }
        
        let peakMemoryInMB = Double(peakMemoryUsage) / 1024.0 / 1024.0
        
        print("🔍 Performance Monitor:")
        print("   Current Memory: \(String(format: "%.2f", memoryInMB)) MB")
        print("   Peak Memory: \(String(format: "%.2f", peakMemoryInMB)) MB")
        
        // Log warning if memory usage is high
        if memoryInMB > 50.0 {
            print("   ⚠️ High memory usage detected!")
        }
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    func getCurrentMemoryUsage() -> UInt64 {
        return getMemoryUsage()
    }
    
    func getPeakMemoryUsage() -> UInt64 {
        return peakMemoryUsage
    }
    
    func resetPeakMemory() {
        peakMemoryUsage = 0
    }
} 