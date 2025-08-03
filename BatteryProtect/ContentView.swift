//
//  ContentView.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var batteryMonitor = BatteryMonitorService()
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAppearing: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // App Title
            TitleView(batteryInfo: batteryMonitor.batteryInfo, colorScheme: colorScheme)
                .offset(y: isAppearing ? 0 : -20)
                .opacity(isAppearing ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAppearing)
            
            // Battery Level Circle
            BatteryCircleView(batteryInfo: batteryMonitor.batteryInfo, colorScheme: colorScheme)
                .scaleEffect(isAppearing ? 1 : 0.8)
                .opacity(isAppearing ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: isAppearing)
            
            // Status Pills Row
            StatusPillsView(batteryInfo: batteryMonitor.batteryInfo, colorScheme: colorScheme)
                .offset(y: isAppearing ? 0 : 20)
                .opacity(isAppearing ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: isAppearing)
            
            // Last Update
            Text(batteryMonitor.batteryInfo.lastUpdateTime.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(Color.subtleTextColor(for: colorScheme))
                .offset(y: isAppearing ? 0 : 20)
                .opacity(isAppearing ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: isAppearing)
        }
        .padding(16)
        .frame(width: 320, height: 240)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.mainBackgroundColor(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.mainBorderColor(for: colorScheme), lineWidth: 1)
                )
        )
        .onAppear {
            batteryMonitor.startMonitoring()
            withAnimation {
                isAppearing = true
            }
        }
        .onDisappear {
            batteryMonitor.stopMonitoring()
        }
    }
}

#Preview {
    ContentView()
}
