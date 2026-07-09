# DockSwitch

**Automatic audio device switching for Mac users who move between desks.**

DockSwitch is a lightweight macOS menu bar app that detects *where* you're working — by dock, Wi-Fi network, and location — and switches your default microphone and speakers to match. Plug into your desk at home and your Yeti mic takes over; dock at the office and your conference speaker is ready before your first meeting.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)

<!-- TODO: add a screenshot of the popover here: ![DockSwitch popover](Design/screenshot.png) -->

## Features

- **Profiles per location** — bundle a preferred mic, speaker, and camera under a name like "Home" or "Work"
- **Automatic switching** — profiles activate on their own based on the dock you're connected to, your Wi-Fi network, and/or a location geofence
- **Manual control** — one click applies any profile; manual override pauses auto mode until you release it
- **Smart matching** — profiles matching more signals win; nothing switches unless confidence is high
- **Menu bar native** — lives quietly in the menu bar; hover the icon to see the active profile and devices
- **Private by design** — no network calls, no analytics; everything stays on your Mac

## Install

1. Download `DockSwitch-x.y.z.zip` from the [latest release](../../releases/latest)
2. Unzip it and drag **DockSwitch.app** into your **Applications** folder
3. Open it. Because DockSwitch is a free, unsigned app, macOS will block the first launch:
   - macOS 15 (Sequoia) and later: open **System Settings → Privacy & Security**, scroll down, and click **"Open Anyway"** next to the DockSwitch message, then confirm
   - macOS 14 (Sonoma): right-click DockSwitch.app → **Open** → **Open**
4. Look for the dock icon in your menu bar. Grant **Location** access when prompted — it powers geofence matching and improves Wi-Fi detection (macOS hides Wi-Fi names from apps without it)

> **Icon not showing?** If your menu bar is crowded (especially on a notched MacBook), macOS may hide new icons. Free up space by removing items you don't need (⌘-drag them off, or trim modules in System Settings → Control Center), or use a menu bar manager like [Ice](https://icemenubar.app/).

## Getting Started

1. Click the DockSwitch icon → **New**
2. Name the profile ("Home", "Office", ...)
3. Pick match rules: use **Use current dock** / **Use current Wi-Fi** to grab what's detected right now, and optionally set a location + radius on the map
4. Choose the **Preferred microphone** and **Preferred speaker** for that setup
5. Save. With **Auto Mode** on, the profile applies whenever its signals match

Hover the menu bar icon anytime to see the active profile and its devices. Right-click the icon (or use the button at the bottom of the popover) to quit.

## Important: how apps pick up your devices

DockSwitch sets the **macOS system default** input and output devices (including the alert sound output). What happens next depends on the app:

| App | Behavior |
|---|---|
| FaceTime, Safari, system sounds | Follow the system default automatically ✅ |
| Zoom | Set mic/speaker to **"Same as System"** once, then follows ✅ |
| Chrome / Edge (and web apps like Clipchamp, Meet) | Follow only when the site's device picker is set to the **"Default — ..."** entry. If a specific device was ever chosen, that choice sticks — reselect "Default" once |
| Microsoft Teams (new client) | Does **not** follow the macOS default — Teams keeps its own selection under **Teams Settings → Devices**. Pick your dock's devices there once per setup; Teams remembers and re-selects them whenever those devices are present. (Teams in the browser follows the system default.) |

**Cameras:** macOS has no system-wide "default camera," so every app chooses its own. DockSwitch stores your camera preference as a reference, but you select the camera inside each app.

## Troubleshooting

- **Wi-Fi shows "unavailable"** — grant Location access (System Settings → Privacy & Security → Location Services). macOS redacts Wi-Fi network names from apps without it.
- **Location permission stuck** — reset it and relaunch:
  ```bash
  tccutil reset Location com.dockswitch.menuapp
  ```
- **A profile isn't auto-applying** — open the popover and check "Best match". Auto-apply requires 70%+ of the profile's own rules to match, and manual override must be cleared.

## Building from Source

Requires macOS 14+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/Stephonomon/DockSwitch.git
cd DockSwitch
./scripts/run-dockswitch-app.sh    # debug build, assembles and launches the .app
```

Other scripts:

- `./scripts/test.sh` — run the test suite (wraps `swift test` with the framework paths Command Line Tools need)
- `./scripts/package-release.sh [version]` — build a distributable, ad-hoc-signed `DockSwitch.app` + zip in `dist/`

Releases are automated: pushing a `v*` tag (e.g. `v1.0.0`) triggers the [release workflow](.github/workflows/release.yml), which packages the app and publishes it with the zip attached.

### Project layout

- `Sources/DockSwitch/` — app entry, state, menu bar controller
  - `Services/` — context detection (dock/Wi-Fi/location), profile matching, CoreAudio switching, persistence
  - `Views/` — SwiftUI popover and profile editor
  - `Models/` — profiles, matching rules, detection context
- `Tests/DockSwitchTests/` — matcher and parser tests

### How matching works

Each profile can match on dock name (substring), Wi-Fi SSID (exact, case-insensitive), and a geofence. Signals carry weights (dock 0.4, Wi-Fi 0.35, location 0.25); profiles are ranked by total matched weight so more specific matches win, and auto-apply requires 70% of a profile's own rules to match. Context refreshes every 20 seconds off the main thread; the expensive nearby-Wi-Fi scan only runs when the profile editor is open or you click Refresh.

## License

[MIT](LICENSE)
