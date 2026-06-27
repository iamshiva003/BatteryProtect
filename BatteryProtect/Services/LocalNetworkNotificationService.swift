//
//  LocalNetworkNotificationService.swift
//  BatteryProtect
//
//  Created by Antigravity Agent on 2026-06-27.
//

#if os(macOS)
import Foundation
import MultipeerConnectivity

class LocalNetworkNotificationService: NSObject, ObservableObject {
    static let shared = LocalNetworkNotificationService()
    
    private let serviceType = "battery-prot"
    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    
    @Published var connectedPeersCount: Int = 0
    @Published var connectionStatus: String = "Idle"
    
    // Deduplication tracker
    private var lastSentDate: Date?
    private var lastSentLevel: Double?
    
    private override init() {
        let name = Host.current().localizedName ?? "macOS-Host"
        // Multipeer ID display name limit is 63 bytes in UTF-8
        let displayName = String(name.prefix(63))
        self.myPeerID = MCPeerID(displayName: displayName)
        
        super.init()
        
        setupSession()
        
        // Listen to settings changes to start/stop browsing dynamically
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        updateBrowsingState()
    }
    
    private func setupSession() {
        self.session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.session?.delegate = self
    }
    
    @objc private func handleSettingsChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateBrowsingState()
        }
    }
    
    private func updateBrowsingState() {
        let enableLocalWiFiSync = UserDefaults.standard.object(forKey: "enableLocalWiFiSync") as? Bool ?? true
        if enableLocalWiFiSync {
            startBrowsing()
        } else {
            stopBrowsing()
        }
    }
    
    func startBrowsing() {
        guard browser == nil else { return }
        
        print("LocalNetworkNotificationService: Starting network browser for service '\(serviceType)'...")
        self.browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        self.browser?.delegate = self
        self.browser?.startBrowsingForPeers()
        
        connectionStatus = "Searching..."
    }
    
    func stopBrowsing() {
        guard browser != nil else { return }
        
        print("LocalNetworkNotificationService: Stopping network browser.")
        browser?.stopBrowsingForPeers()
        browser = nil
        
        // Clear active session to disconnect peers
        session?.disconnect()
        
        connectionStatus = "Idle"
        connectedPeersCount = 0
    }
    
    /// Sends a high battery status alert to all connected iPhone companion peers.
    /// - Parameters:
    ///   - level: Current battery level (0.0 to 1.0)
    ///   - threshold: Configured high threshold percentage
    func sendLocalHighBatteryAlert(level: Double, threshold: Double) {
        guard let session = session, !session.connectedPeers.isEmpty else {
            print("LocalNetworkNotificationService: No iOS peers connected to send local Wi-Fi alert.")
            return
        }
        
        let now = Date()
        
        // Deduplicate local alerts: limit to once per 5 minutes for the same level range
        if let lastDate = lastSentDate, now.timeIntervalSince(lastDate) < 300 {
            if let lastLevel = lastSentLevel, abs(level - lastLevel) < 0.01 {
                print("LocalNetworkNotificationService: Alert deduplicated. Already sent Wi-Fi alert for level \(level) recently.")
                return
            }
        }
        
        print("LocalNetworkNotificationService: Sending local high battery alert to \(session.connectedPeers.count) peer(s)...")
        
        let messageDict: [String: Any] = [
            "type": "high-battery",
            "level": level,
            "threshold": threshold,
            "timestamp": now.timeIntervalSince1970
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: messageDict, options: [])
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            
            self.lastSentDate = now
            self.lastSentLevel = level
            print("LocalNetworkNotificationService: Successfully broadcasted local network notification alert.")
        } catch {
            print("LocalNetworkNotificationService: Error serializing or sending network notification: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension LocalNetworkNotificationService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let session = session else { return }
        
        print("LocalNetworkNotificationService: Found companion peer: \(peerID.displayName). Sending invitation...")
        
        // Auto-invite any found companion app
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("LocalNetworkNotificationService: Lost companion peer: \(peerID.displayName)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("LocalNetworkNotificationService: Failed to start browsing: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.connectionStatus = "Search Failed"
        }
    }
}

// MARK: - MCSessionDelegate
extension LocalNetworkNotificationService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectedPeersCount = session.connectedPeers.count
            
            switch state {
            case .connecting:
                print("LocalNetworkNotificationService: Connecting to \(peerID.displayName)...")
                self.connectionStatus = "Connecting..."
            case .connected:
                print("LocalNetworkNotificationService: Connected to \(peerID.displayName)!")
                self.connectionStatus = "Connected"
            case .notConnected:
                print("LocalNetworkNotificationService: Disconnected from \(peerID.displayName).")
                if session.connectedPeers.isEmpty {
                    self.connectionStatus = "Searching..."
                }
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // No data expected from client in basic setup, but available for bidirectional sync later
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
#endif
