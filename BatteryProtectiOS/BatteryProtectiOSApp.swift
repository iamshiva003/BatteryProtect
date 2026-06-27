//
//  BatteryProtectiOSApp.swift
//  BatteryProtect
//
//  Created by Antigravity Agent on 2026-06-27.
//

#if os(iOS)
import SwiftUI
import UserNotifications

@main
struct BatteryProtectiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            iOSContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        // Register for push notifications on startup
        application.registerForRemoteNotifications()
        
        return true
    }
    
    // Handlers for remote notification registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Successfully registered for push notifications. Token: \(tokenString)")
        // Setup CloudKit database subscriptions (only if iCloud entitlement is active)
        // CloudKitReceiverService.shared.setupCloudKitSubscription()
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Foreground notification display handling
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
#endif
