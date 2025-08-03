# BatteryProtect

A macOS status bar application that monitors battery health and provides intelligent alerts to preserve battery longevity.

## Features

- **Real-time Battery Monitoring**: Continuously monitors battery level, charging status, and health
- **Smart Alerts**: Notifies when battery is low (≤20%) or high (≥80%) while plugged in
- **Battery Health Tracking**: Displays battery health percentage and status
- **Status Bar Integration**: Clean status bar icon that changes based on battery state
- **Modern UI**: Beautiful, animated interface with dark/light mode support

## Architecture

The project follows a modular architecture with clear separation of concerns:

### 📁 Project Structure

```
BatteryProtect/
├── Models/
│   └── BatteryInfo.swift          # Data model for battery information
├── Services/
│   ├── BatteryMonitorService.swift # Core battery monitoring logic
│   └── StatusBarService.swift     # Status bar management
├── Views/
│   ├── BatteryCircleView.swift    # Battery level circle component
│   ├── StatusPillsView.swift      # Status pills component
│   └── TitleView.swift            # App title component
├── Utils/
│   └── ColorExtensions.swift      # Theme-aware color utilities
├── ContentView.swift              # Main UI composition
├── BatteryProtectApp.swift        # App entry point
└── Assets.xcassets/              # App resources
```

### 🏗️ Architecture Components

#### Models
- **BatteryInfo**: Centralized data structure containing all battery-related information
- Includes computed properties for battery state, icons, and colors

#### Services
- **BatteryMonitorService**: Handles battery monitoring, alerts, and data updates
- **StatusBarService**: Manages status bar item, popover, and icon updates

#### Views
- **BatteryCircleView**: Animated circular battery level indicator
- **StatusPillsView**: Power source and health status pills
- **TitleView**: App title with dynamic icon and animations

#### Utils
- **ColorExtensions**: Theme-aware color utilities for consistent UI

### 🔄 Data Flow

1. **BatteryMonitorService** continuously monitors battery state
2. Updates **BatteryInfo** model with latest data
3. **StatusBarService** updates status bar icon based on battery state
4. **ContentView** composes UI components using the shared **BatteryInfo**
5. Individual view components handle their own animations and interactions

### 🎨 UI Components

- **Modular Design**: Each UI component is self-contained and reusable
- **Theme Support**: Automatic dark/light mode adaptation
- **Animations**: Smooth transitions and state-based animations
- **Accessibility**: Proper tooltips and hover states

## Benefits of Modular Architecture

### ✅ Maintainability
- Clear separation of concerns
- Easy to locate and modify specific functionality
- Reduced code duplication

### ✅ Testability
- Isolated components can be tested independently
- Service layer can be mocked for UI testing

### ✅ Scalability
- Easy to add new features without affecting existing code
- New UI components can be added without changing core logic

### ✅ Reusability
- UI components can be reused across different views
- Services can be shared between different parts of the app

## Development

### Requirements
- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

### Building
1. Open `BatteryProtect.xcodeproj` in Xcode
2. Select your target device/simulator
3. Build and run the project

### Adding New Features

#### Adding a New Service
1. Create a new file in the `Services/` directory
2. Follow the ObservableObject pattern for reactive updates
3. Inject dependencies through initializer

#### Adding a New View Component
1. Create a new file in the `Views/` directory
2. Accept `BatteryInfo` and `ColorScheme` as parameters
3. Use the color utilities for consistent theming

#### Adding New Data Properties
1. Update the `BatteryInfo` model
2. Update the `BatteryMonitorService` to populate the new data
3. Update UI components to display the new information

## License

This project is licensed under the MIT License. 