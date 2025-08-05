//
//  SignalHandlerService.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import Foundation
import Darwin
import AppKit

protocol SignalHandlerServiceDelegate: AnyObject {
    func handleForceQuit()
}

class SignalHandlerService: NSObject {
    weak var delegate: SignalHandlerServiceDelegate?
    
    func setupSignalHandlers() {
        // Handle SIGTERM (normal termination)
        signal(SIGTERM) { _ in
            print("🛑 SIGTERM received - cleaning up")
            DispatchQueue.main.async {
                SignalHandlerService.shared?.delegate?.handleForceQuit()
                NSApp.terminate(nil)
            }
        }
        
        // Handle SIGINT (Ctrl+C)
        signal(SIGINT) { _ in
            print("🛑 SIGINT received - cleaning up")
            DispatchQueue.main.async {
                SignalHandlerService.shared?.delegate?.handleForceQuit()
                NSApp.terminate(nil)
            }
        }
        
        // Handle SIGQUIT (force quit)
        signal(SIGQUIT) { _ in
            print("🛑 SIGQUIT received - force quitting")
            DispatchQueue.main.async {
                SignalHandlerService.shared?.delegate?.handleForceQuit()
                exit(0)
            }
        }
    }
    
    // Static reference for signal handlers
    static var shared: SignalHandlerService?
    
    override init() {
        super.init()
        SignalHandlerService.shared = self
    }
} 