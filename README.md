# NetSecOps QML - Network Security Dashboard

A complete QML port of the NetSecOps web application, providing identical functionality and visual design in a native desktop application.

## Features

- **Dashboard**: Network security overview with real-time statistics
- **Network Discovery**: Scan and enumerate network hosts
- **Network Map**: Interactive topology visualization
- **Operations**: Remote command execution and file operations
- **Credentials**: Secure credential management
- **Activity**: Real-time monitoring and audit logs

## Design System

- **Dark Cyber Theme**: Matching the original web version
- **Color Scheme**: 
  - Background: `#0a0e1a`
  - Cards: `#0f1419`
  - Primary: `#3b82f6` (Cyber Blue)
  - Accent: `#06b6d4` (Electric Cyan)
  - Success: `#16a34a`
  - Warning: `#eab308`
  - Destructive: `#dc2626`

## Building

### Prerequisites
- Qt 6.2 or later
- CMake 3.16+ or qmake
- C++17 compiler

### Using CMake
```bash
mkdir build
cd build
cmake ..
cmake --build .
```

### Using qmake
```bash
qmake NetSecOps.pro
make
```

## Project Structure

```
NetSecOps-QML/
├── main.cpp                 # Application entry point
├── qml/
│   ├── main.qml            # Main application window
│   ├── MainLayout.qml      # Layout with navigation
│   └── Navigation.qml      # Sidebar navigation
├── pages/                  # Application pages
│   ├── Dashboard.qml
│   ├── NetworkDiscovery.qml
│   ├── NetworkMap.qml
│   ├── Operations.qml
│   ├── Credentials.qml
│   └── Activity.qml
├── components/             # Reusable UI components
│   ├── Card.qml
│   ├── Button.qml
│   ├── Badge.qml
│   ├── Input.qml
│   └── Progress.qml
├── CMakeLists.txt          # CMake build configuration
├── NetSecOps.pro          # qmake project file
└── qml.qrc                # Qt resource file
```

## Components

### Card
Reusable card component with title, description, and content area.

### Button
Multi-variant button component (default, cyber, outline, ghost) with icon support.

### Badge
Status badges with different variants (success, warning, destructive, outline).

### Input
Styled text input field matching the web design.

### Progress
Animated progress bar component.

## Pages

### Dashboard
- Network statistics overview
- Recent scan activity
- Security status indicators

### Network Discovery
- Scan configuration
- Real-time progress monitoring
- Host discovery results
- Scan history

### Network Map
- Interactive network topology
- Device visualization with tooltips
- Network statistics sidebar
- Animated scanning overlay

### Operations
- Remote command execution
- File transfer operations
- Active job monitoring
- Quick execute dialog

### Credentials
- Secure credential storage
- Multiple authentication types
- Security settings
- Password visibility toggle

### Activity
- Real-time activity logs
- Security alerts
- Filtering and search
- Detailed log inspection

## Customization

The application uses a consistent color scheme defined in each component. To customize:

1. Update color values in component files
2. Modify the gradient definitions
3. Adjust animation timings and effects

## License

This QML application maintains the same functionality and design as the original web version while providing native desktop performance and integration.