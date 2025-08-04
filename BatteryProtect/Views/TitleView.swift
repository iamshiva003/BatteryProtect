//
//  TitleView.swift
//  BatteryProtect
//
//  Created by Shivakumar Patil on 01/08/25.
//

import SwiftUI

struct TitleView: View {
    let batteryInfo: BatteryInfo
    let colorScheme: ColorScheme
    @State private var isHovering: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    
    private var powerColor: Color {
        Color.batteryColor(for: batteryInfo, colorScheme: colorScheme)
    }
    
    private var backgroundColor: Color {
        Color.backgroundColor(for: colorScheme)
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                powerColor.opacity(colorScheme == .dark ? 0.35 : 0.12),
                backgroundColor
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var textColor: Color {
        Color.textColor(for: colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Group {
                if batteryInfo.isCharging {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(powerColor)
                        .scaleEffect(isHovering ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
                } else {
                    Image(systemName: batteryInfo.batteryIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(powerColor)
                        .scaleEffect(pulseScale)
                        .animation(
                            batteryInfo.isCriticalBattery ? 
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                            .spring(response: 0.3, dampingFraction: 0.6),
                            value: pulseScale
                        )
                }
            }
            
            Text("Battery")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(textColor)
            + Text("Protect")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(powerColor)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(powerColor.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
                )
                .scaleEffect(isHovering ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .onAppear {
            if batteryInfo.isCriticalBattery {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            }
        }
        .onChange(of: batteryInfo.isCriticalBattery) {
            if batteryInfo.isCriticalBattery {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    pulseScale = 1.0
                }
            }
        }
    }
} 