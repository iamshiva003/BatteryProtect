//
//  CloudKitReceiverService.swift
//  BatteryProtect
//
//  Created by Antigravity Agent on 2026-06-27.
//

#if os(iOS)
import Foundation
import CloudKit
import UserNotifications
import UIKit
import Combine

class CloudKitReceiverService: ObservableObject {
    static let shared = CloudKitReceiverService()
    
    private var _container: CKContainer?
    private var _privateDatabase: CKDatabase?
    private let subscriptionID = "high-battery-alert-subscription"
    
    private var container: CKContainer? {
        // Specifying the identifier explicitly prevents CKContainer.default() from crashing
        // when the default container cannot be resolved due to missing entitlements.
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
    
    @Published var subscriptionStatus: String = "iCloud Sync Disabled"
    @Published var icloudAccountStatus: String = "iCloud Sync Disabled"
    @Published var notificationPermissionGranted: Bool = false
    
    private init() {
        checkNotificationPermission()
    }
    
    func enableCloudKitSync() {
        checkCloudKitAccountStatus()
        setupCloudKitSubscription()
    }
    
    func checkCloudKitAccountStatus() {
        guard let container = container else {
            DispatchQueue.main.async {
                self.icloudAccountStatus = "Entitlements Missing"
            }
            return
        }
        
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.icloudAccountStatus = "Error: \(error.localizedDescription)"
                    return
                }
                switch status {
                case .available:
                    self?.icloudAccountStatus = "Available"
                case .noAccount:
                    self?.icloudAccountStatus = "No iCloud Account Signed In"
                case .restricted:
                    self?.icloudAccountStatus = "iCloud Restricted"
                case .couldNotDetermine:
                    self?.icloudAccountStatus = "Could Not Determine Account Status"
                @unknown default:
                    self?.icloudAccountStatus = "Unknown"
                }
            }
        }
    }
    
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func setupCloudKitSubscription() {
        guard let privateDatabase = privateDatabase else {
            DispatchQueue.main.async {
                self.subscriptionStatus = "Entitlements Missing"
            }
            return
        }
        
        // First check if the subscription already exists
        privateDatabase.fetch(withSubscriptionID: subscriptionID) { [weak self] subscription, error in
            guard let self = self else { return }
            
            if let subscription = subscription {
                print("CloudKitReceiverService: Subscription already exists: \(subscription.subscriptionID)")
                DispatchQueue.main.async {
                    self.subscriptionStatus = "Active"
                }
                return
            }
            
            // Subscription does not exist or fetch failed, create a new subscription
            let predicate = NSPredicate(value: true)
            let querySubscription = CKQuerySubscription(
                recordType: "BatteryAlert",
                predicate: predicate,
                subscriptionID: self.subscriptionID,
                options: .firesOnRecordCreation
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.alertBody = "Battery protect: Charging has reached the high threshold limit!"
            notificationInfo.soundName = "default"
            notificationInfo.shouldBadge = true
            notificationInfo.shouldSendContentAvailable = true
            
            querySubscription.notificationInfo = notificationInfo
            
            privateDatabase.save(querySubscription) { savedSubscription, saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        print("CloudKitReceiverService: Failed to save subscription: \(saveError.localizedDescription)")
                        self.subscriptionStatus = "Failed: \(saveError.localizedDescription)"
                    } else {
                        print("CloudKitReceiverService: Successfully created subscription.")
                        self.subscriptionStatus = "Active (Registered)"
                    }
                }
            }
        }
    }
    
    /// Helper method to write a test alert record into CloudKit, which immediately tests the push notification flow.
    func sendTestNotification(completion: @escaping (Bool, String) -> Void) {
        guard let privateDatabase = privateDatabase else {
            completion(false, "iCloud capability not configured in Xcode targets.")
            return
        }
        
        let record = CKRecord(recordType: "BatteryAlert")
        record["level"] = 0.85 as CKRecordValue
        record["threshold"] = 0.80 as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        
        privateDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, "Successfully sent test record!")
                }
            }
        }
    }
}
#endif
