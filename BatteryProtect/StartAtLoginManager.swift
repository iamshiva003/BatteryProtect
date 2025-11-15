//
//  StartAtLoginManager.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import Foundation
import ServiceManagement

enum StartAtLoginError: Error, LocalizedError {
    case unavailable
    case registrationFailed
    case unregistrationFailed
    
    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Start at Login is unavailable on this version of macOS."
        case .registrationFailed:
            return "Failed to enable Start at Login."
        case .unregistrationFailed:
            return "Failed to disable Start at Login."
        }
    }
}

struct StartAtLoginManager {
    static var isAvailable: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }
    
    @discardableResult
    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                return true
            default:
                return false
            }
        } else {
            return false
        }
    }
    
    static func setEnabled(_ enabled: Bool) throws {
        guard isAvailable else { throw StartAtLoginError.unavailable }
        if #available(macOS 13.0, *) {
            if enabled {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    throw StartAtLoginError.registrationFailed
                }
            } else {
                do {
                    try SMAppService.mainApp.unregister()
                } catch {
                    throw StartAtLoginError.unregistrationFailed
                }
            }
        }
    }
}
