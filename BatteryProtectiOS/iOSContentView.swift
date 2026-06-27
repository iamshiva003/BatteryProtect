//
//  iOSContentView.swift
//  BatteryProtect
//
//  Created by Antigravity Agent on 2026-06-27.
//

#if os(iOS)
import SwiftUI

struct iOSContentView: View {
    @StateObject private var receiverService = CloudKitReceiverService.shared
    @StateObject private var localReceiverService = LocalNetworkReceiverService.shared
    
    @State private var showingTestStatus = false
    @State private var testStatusMessage = ""
    @State private var isTestSuccessful = false
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Elegant background gradient
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.12, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Decorative background glowing circle
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(y: -150)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Title Header
                    VStack(spacing: 8) {
                        Image(systemName: "battery.100.bolt")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .emerald],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .green.opacity(0.5), radius: 10, x: 0, y: 5)
                            .scaleEffect(isAnimating ? 1.05 : 0.95)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                        
                        Text("BatteryProtect")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("iOS Companion App")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 30)
                    .onAppear {
                        isAnimating = true
                    }
                    
                    // Status Panel Card (Glassmorphic design)
                    VStack(alignment: .leading, spacing: 18) {
                        Text("CONNECTION STATUS")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Status Row 1: iCloud Account
                        StatusRow(
                            title: "iCloud Sync Account",
                            value: receiverService.icloudAccountStatus,
                            iconName: "icloud.fill",
                            iconColor: receiverService.icloudAccountStatus == "Available" ? .blue : .orange
                        )
                        
                        // Status Row 2: Notifications Permission
                        StatusRow(
                            title: "Push Notifications",
                            value: receiverService.notificationPermissionGranted ? "Enabled" : "Disabled",
                            iconName: receiverService.notificationPermissionGranted ? "bell.badge.fill" : "bell.slash.fill",
                            iconColor: receiverService.notificationPermissionGranted ? .green : .red
                        )
                        
                        // Status Row 3: CloudKit Subscription (App Store Production)
                        StatusRow(
                            title: "iCloud Background Sync",
                            value: receiverService.subscriptionStatus,
                            iconName: "arrow.triangle.2.circlepath.icloud.fill",
                            iconColor: receiverService.subscriptionStatus.contains("Active") ? .green : .orange
                        )
                        
                        // Status Row 4: Local Network Connection (Free Testing Channel)
                        StatusRow(
                            title: "Local Wi-Fi Connection",
                            value: localReceiverService.connectionStatus,
                            iconName: "wifi",
                            iconColor: localReceiverService.connectionStatus.contains("Connected") ? .green : .blue
                        )
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // Action Buttons Block
                    VStack(spacing: 16) {
                        
                        // Action 1: Enable Push Notifications (if disabled)
                        if !receiverService.notificationPermissionGranted {
                            Button(action: {
                                receiverService.requestNotificationPermission()
                            }) {
                                HStack {
                                    Image(systemName: "bell.fill")
                                    Text("Enable Push Notifications")
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .cornerRadius(14)
                                .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                            }
                        }
                        
                        // Action 2: Trigger End-to-End Test push notification via CloudKit
                        Button(action: {
                            triggerTestFlow()
                        }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Test iCloud Alert (Paid Dev Account)")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .disabled(!receiverService.notificationPermissionGranted)
                        .opacity(receiverService.notificationPermissionGranted ? 1.0 : 0.6)
                    }
                    .padding(.horizontal, 20)
                    
                    // Success / Error status banners
                    if showingTestStatus {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: isTestSuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(isTestSuccessful ? .green : .red)
                                Text(isTestSuccessful ? "Success!" : "Notice")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            Text(testStatusMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isTestSuccessful ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .transition(.slide)
                    }
                    
                    // Technical Configuration Guide block
                    VStack(alignment: .leading, spacing: 10) {
                        Label("HOW TO CONFIGURE (FREE TESTING)", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("1. Create an **iOS target** named **BatteryProtectiOS**.")
                        Text("2. Add files in **iOSCompanion/** folder to your iOS target.")
                        Text("3. Build and run it on your iPhone.")
                        Text("4. Ensure **both your Mac and iPhone** are on the same Wi-Fi network.")
                        Text("5. The status above will show **Connected to Mac** and alerts will push immediately!")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func triggerTestFlow() {
        testStatusMessage = "Saving test record to your private iCloud Database..."
        isTestSuccessful = true
        showingTestStatus = true
        
        receiverService.sendTestNotification { success, message in
            withAnimation {
                isTestSuccessful = success
                if success {
                    testStatusMessage = "Test record saved. If this iPhone is subscribed and logged in, you should receive a push notification within seconds!"
                } else {
                    testStatusMessage = "iCloud write failed: \(message). Note: CloudKit capabilities require a paid developer account."
                }
            }
        }
    }
}

// Custom view helper for beautiful status rows
struct StatusRow: View {
    let title: String
    let value: String
    let iconName: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

// Support fallback Color helper
extension Color {
    static let emerald = Color(red: 0.1, green: 0.7, blue: 0.4)
}
#endif
