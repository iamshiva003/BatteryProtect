//
//  LocalNetworkReceiverService.swift
//  BatteryProtect
//
//  Created by Antigravity Agent on 2026-06-27.
//

#if os(iOS)
import Foundation
import MultipeerConnectivity
import UserNotifications
import UIKit
import Combine

class LocalNetworkReceiverService: NSObject, ObservableObject {
    static let shared = LocalNetworkReceiverService()
    
    private let serviceType = "battery-prot"
    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    
    @Published var connectedPeersCount: Int = 0
    @Published var connectionStatus: String = "Idle"
    @Published var lastAlertReceivedTime: Date?
    @Published var lastAlertLevel: Double?
    @Published var macBatteryInfo: BatteryInfo?
    
    private override init() {
        let name = UIDevice.current.name
        // Multipeer ID display name limit is 63 bytes in UTF-8
        let displayName = String(name.prefix(63))
        self.myPeerID = MCPeerID(displayName: displayName)
        
        super.init()
        
        setupSession()
        startAdvertising()
    }
    
    private func setupSession() {
        self.session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.session?.delegate = self
    }
    
    func startAdvertising() {
        guard advertiser == nil else { return }
        
        print("LocalNetworkReceiverService: Starting network advertiser for service '\(serviceType)'...")
        self.advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        self.advertiser?.delegate = self
        self.advertiser?.startAdvertisingPeer()
        
        DispatchQueue.main.async {
            self.connectionStatus = "Advertising..."
        }
    }
    
    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        
        DispatchQueue.main.async {
            self.connectionStatus = "Idle"
        }
    }
    
    /// Triggers a local iOS user notification when a payload is received from the Mac app.
    private func triggerLocalNotification(level: Double, threshold: Double) {
        // Request authorization again just in case, but verify it's granted
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("LocalNetworkReceiverService: Cannot present local notification. Permissions are not authorized.")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Laptop Battery Alert"
            content.body = "Your laptop charging has reached your high threshold limit: \(Int(level * 100))% (threshold: \(Int(threshold))%)"
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            
            let request = UNNotificationRequest(
                identifier: "com.batteryprotect.localnetalert",
                content: content,
                trigger: nil // Instantaneous
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("LocalNetworkReceiverService: Failed to schedule local notification: \(error.localizedDescription)")
                } else {
                    print("LocalNetworkReceiverService: Successfully posted local notification to user screen.")
                }
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension LocalNetworkReceiverService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("LocalNetworkReceiverService: Received connection invitation from \(peerID.displayName). Accepting automatically.")
        
        // Accept invitation automatically
        invitationHandler(true, self.session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("LocalNetworkReceiverService: Failed to start advertising: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.connectionStatus = "Setup Failed"
        }
    }
}

// MARK: - MCSessionDelegate
extension LocalNetworkReceiverService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectedPeersCount = session.connectedPeers.count
            
            switch state {
            case .connecting:
                print("LocalNetworkReceiverService: Connecting to \(peerID.displayName)...")
                self.connectionStatus = "Connecting..."
            case .connected:
                print("LocalNetworkReceiverService: Connected to \(peerID.displayName)!")
                self.connectionStatus = "Connected to \(peerID.displayName)"
            case .notConnected:
                print("LocalNetworkReceiverService: Disconnected from \(peerID.displayName).")
                if session.connectedPeers.isEmpty {
                    self.connectionStatus = "Advertising..."
                    self.macBatteryInfo = nil
                }
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("LocalNetworkReceiverService: Received data package from peer \(peerID.displayName). Processing...")
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let type = json["type"] as? String {
                
                if type == "high-battery",
                   let level = json["level"] as? Double,
                   let threshold = json["threshold"] as? Double {
                    
                    print("LocalNetworkReceiverService: Parsed alert (Level: \(level), Threshold: \(threshold)). Triggering notification.")
                    
                    DispatchQueue.main.async {
                        self.lastAlertReceivedTime = Date()
                        self.lastAlertLevel = level
                    }
                    
                    triggerLocalNotification(level: level, threshold: threshold)
                } else if type == "status-update" {
                    let level = json["level"] as? Double ?? 1.0
                    let systemPercentage = json["systemPercentage"] as? Int ?? 100
                    let chargingStatus = json["chargingStatus"] as? String ?? "Unknown"
                    let powerSource = json["powerSource"] as? String ?? "Unknown"
                    let health = json["health"] as? String ?? "Unknown"
                    let healthPercentage = json["healthPercentage"] as? Int ?? 100
                    let cycleCountRaw = json["cycleCount"] as? Int ?? -1
                    let timeToFullChargeMinutesRaw = json["timeToFullChargeMinutes"] as? Int ?? -1
                    let timeToEmptyMinutesRaw = json["timeToEmptyMinutes"] as? Int ?? -1
                    
                    let cycleCount = cycleCountRaw >= 0 ? cycleCountRaw : nil
                    let timeToFullChargeMinutes = timeToFullChargeMinutesRaw >= 0 ? timeToFullChargeMinutesRaw : nil
                    let timeToEmptyMinutes = timeToEmptyMinutesRaw >= 0 ? timeToEmptyMinutesRaw : nil
                    
                    let info = BatteryInfo(
                        level: Float(level),
                        powerSource: powerSource,
                        chargingStatus: chargingStatus,
                        health: health,
                        healthPercentage: healthPercentage,
                        lastUpdateTime: Date(),
                        systemPercentage: systemPercentage,
                        cycleCount: cycleCount,
                        timeToEmptyMinutes: timeToEmptyMinutes,
                        timeToFullChargeMinutes: timeToFullChargeMinutes
                    )
                    
                    DispatchQueue.main.async {
                        self.macBatteryInfo = info
                    }
                }
            }
        } catch {
            print("LocalNetworkReceiverService: Error parsing message: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Shared iOS BatteryInfo Model
struct BatteryInfo {
    let level: Float
    let powerSource: String
    let chargingStatus: String
    let health: String
    let healthPercentage: Int
    let lastUpdateTime: Date
    let systemPercentage: Int
    let cycleCount: Int?
    let timeToEmptyMinutes: Int?
    let timeToFullChargeMinutes: Int?
    
    init(
        level: Float = 1.0,
        powerSource: String = "Unknown",
        chargingStatus: String = "Unknown",
        health: String = "Unknown",
        healthPercentage: Int = 100,
        lastUpdateTime: Date = Date(),
        systemPercentage: Int = 100,
        cycleCount: Int? = nil,
        timeToEmptyMinutes: Int? = nil,
        timeToFullChargeMinutes: Int? = nil
    ) {
        self.level = level
        self.powerSource = powerSource
        self.chargingStatus = chargingStatus
        self.health = health
        self.healthPercentage = healthPercentage
        self.lastUpdateTime = lastUpdateTime
        self.systemPercentage = systemPercentage
        self.cycleCount = cycleCount
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.timeToFullChargeMinutes = timeToFullChargeMinutes
    }
}

extension BatteryInfo {
    var isCharging: Bool {
        chargingStatus == "Charging"
    }
    
    var isPluggedIn: Bool {
        powerSource == "Power Adapter"
    }
    
    var batteryIcon: String {
        if level <= 0.05 {
            return "battery.0.circle.fill"
        } else if level <= 0.25 {
            return "battery.25.circle.fill"
        } else if level <= 0.50 {
            return "battery.50.circle.fill"
        } else if level <= 0.75 {
            return "battery.75.circle.fill"
        } else {
            return "battery.100.circle.fill"
        }
    }
    
    var batteryColor: String {
        if isPluggedIn {
            return "green"
        }
        let percent = level * 100.0
        if percent < 20.0 {
            return "red"
        }
        return "orange"
    }
}
#endif
