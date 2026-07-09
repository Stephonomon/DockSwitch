# DockSwitch

DockSwitch is a macOS menu bar app that helps switch audio/video defaults based on context (dock, Wi-Fi, and location) so moving between setups is faster and less error-prone.

## Current Status

- Menu bar app with profile-based context matching
- Auto mode and manual override support
- Profile editor with device dropdowns for microphone, speaker, and camera
- Dock detection suggestions and Thunderbolt dock candidate detection
- Wi-Fi detection suggestions and refresh actions
- Map-based location + radius controls
- CoreAudio default input/output switching
- Bundled `.app` launcher script for better permissions behavior
- Liquid-glass style UI pass in progress
- Icon concept assets in `Design/`

## Project Structure

- App entry: `Sources/DockSwitch/AppMain.swift`
- App state: `Sources/DockSwitch/AppState.swift`
- Menu/editor UI: `Sources/DockSwitch/Views/StatusMenuView.swift`
- Context detection: `Sources/DockSwitch/Services/ContextDetector.swift`
- Dock hardware detection: `Sources/DockSwitch/Services/DockHardwareDetector.swift`
- Audio switching: `Sources/DockSwitch/Services/AudioDeviceManager.swift`
- Device discovery: `Sources/DockSwitch/Services/DeviceDiscoveryService.swift`
- Profile matching: `Sources/DockSwitch/Services/ProfileMatcher.swift`
- Profile persistence: `Sources/DockSwitch/Services/ProfileStore.swift`
- Models: `Sources/DockSwitch/Models/Profile.swift`
- Launcher script: `scripts/run-dockswitch-app.sh`
- Icon concept: `Design/DockSwitch-icon-concept.svg`
- Icon notes: `Design/ICON_NOTES.md`

## Requirements

- macOS 14+
- Xcode Command Line Tools

Install tools if needed:

```bash
xcode-select --install
```

## Build And Run

Recommended mode (bundled app identity `com.dockswitch.menuapp`):

```bash
cd "/Users/proctors/Library/CloudStorage/OneDrive-Children'sHospitalofPhiladelphia/Documents/Dynamic Dock App"
./scripts/run-dockswitch-app.sh
```

Development mode:

```bash
cd "/Users/proctors/Library/CloudStorage/OneDrive-Children'sHospitalofPhiladelphia/Documents/Dynamic Dock App"
xcrun swift run --disable-sandbox DockSwitch
```

## Permissions

DockSwitch uses Location Services for location matching and Wi-Fi scan behavior.

If location permission gets stuck:

```bash
tccutil reset Location com.dockswitch.menuapp
./scripts/run-dockswitch-app.sh
```

## Matching Logic (Current)

- Dock: string match against detected dock candidates
- Wi-Fi: exact SSID match
- Location: geofence distance check using latitude/longitude/radius
- Confidence score: combined signal score with auto-apply threshold

## Known Constraints

- Camera defaulting is app-dependent; DockSwitch stores camera preference but cannot force all third-party apps to switch.
- Wi-Fi scan results are still subject to macOS API/privacy behavior and environment conditions.
- The current SwiftUI `Map(coordinateRegion:)` API logs a deprecation warning on macOS 14+, but functionality still works.

## Design Direction

Current visual direction is liquid-glass inspired:

- Frosted cards and layered translucency
- Soft gradient/glow atmosphere
- Clear typography hierarchy with compact controls

Use `Design/ICON_NOTES.md` for converting the icon concept SVG into `.iconset` / `.icns`.
