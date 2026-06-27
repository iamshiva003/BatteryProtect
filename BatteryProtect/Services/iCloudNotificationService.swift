//
//  iCloudNotificationService.swift
//  BatteryProtect
//
//  Created by Antigravity Agent on 2026-06-27.
//

import Foundation
import CloudKit
import Security

class iCloudNotificationService {
    static let shared = iCloudNotificationService()
    
    private var _container: CKContainer?
    private var _privateDatabase: CKDatabase?
    
    private var container: CKContainer? {
        #if os(macOS)
        // Check if the application actually has the iCloud capability entitlement
        // to prevent EXC_BREAKPOINT crash from Apple's framework.
        guard hasiCloudEntitlement() else {
            print("iCloudNotificationService: com.apple.developer.icloud-services entitlement not present. CloudKit is disabled.")
            return nil
        }
        #endif
        
        if _container == nil {
            _container = CKContainer(identifier: "iCloud.com.batteryprotect")
        }
        return _container
    }
    
    private var privateDatabase: CKDatabase? {
        if _privateDatabase == nil {
            _privateDatabase = container?.privateCloudDatabase
        }
        return _privateDatabase
    }
    
    // Deduplication tracker
    private var lastSentDate: Date?
    private var lastSentLevel: Double?
    
    private init() {
        // Safe, lazy initialization
    }
    
    #if os(macOS)
    /// Safe runtime check to determine if the iCloud/CloudKit entitlement is compiled into the app's signature.
    private func hasiCloudEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return false
        }
        
        let entitlementName = "com.apple.developer.icloud-services" as CFString
        var error: Unmanaged<CFError>?
        
        if let _ = SecTaskCopyValueForEntitlement(task, entitlementName, &error) {
            return true
        } else {
            if let err = error?.takeRetainedValue() {
                print("iCloudNotificationService: Entitlement query error: \(err.localizedDescription)")
            }
            return false
        }
    }
    #endif
    
    /// Sends a high battery push notification to the user's iCloud devices by saving a record to the private CloudKit database.
    /// - Parameters:
    ///   - level: The current battery percentage (0.0 to 1.0)
    ///   - threshold: The user-configured high threshold (e.g. 80.0)
    func sendHighBatteryAlert(level: Double, threshold: Double) {
        let now = Date()
        
        // Deduplicate: Don't send multiple alerts for the same percentage within 5 minutes
        if let lastDate = lastSentDate, now.timeIntervalSince(lastDate) < 300 {
            if let lastLevel = lastSentLevel, abs(level - lastLevel) < 0.01 {
                print("iCloudNotificationService: Alert deduplicated. Already sent push for level \(level) recently.")
                return
            }
        }
        
        print("iCloudNotificationService: Attempting to send high battery push notification (Level: \(Int(level * 100))%, Threshold: \(Int(threshold))%)")
        
        guard let container = container, let privateDatabase = privateDatabase else {
            print("iCloudNotificationService: CloudKit container not configured or entitlements are missing. Sync cancelled.")
            return
        }
        
        // Check iCloud account status first to fail gracefully if user isn't logged in
        container.accountStatus { [weak self] status, error in
            guard let self = self else { return }
            
            if let error = error {
                print("iCloudNotificationService: Error checking iCloud account status: \(error.localizedDescription)")
                return
            }
            
            guard status == .available else {
                print("iCloudNotificationService: iCloud account not available. Status: \(status.rawValue)")
                return
            }
            
            // Create a CKRecord of type "BatteryAlert"
            let record = CKRecord(recordType: "BatteryAlert")
            record["level"] = level as CKRecordValue
            record["threshold"] = threshold as CKRecordValue
            record["timestamp"] = now as CKRecordValue
            
            // Save to private database
            privateDatabase.save(record) { [weak self] savedRecord, saveError in
                if let saveError = saveError {
                    print("iCloudNotificationService: Failed to save record to CloudKit: \(saveError.localizedDescription)")
                } else {
                    print("iCloudNotificationService: Successfully saved BatteryAlert record to CloudKit.")
                    self?.lastSentDate = now
                    self?.lastSentLevel = level
                }
            }
        }
    }
}
