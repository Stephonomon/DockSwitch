import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let state: AppState
    private var outsideClickMonitor: Any?
    private var stateObservation: AnyCancellable?

    init(state: AppState) {
        self.state = state
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        popover.contentSize = NSSize(width: 380, height: 560)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: StatusMenuView(state: state))

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "DockSwitch")
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateToolTip()
        stateObservation = state.objectWillChange.sink { [weak self] _ in
            // objectWillChange fires before the mutation lands; hop to the
            // next main-actor turn so the tooltip reads the new values.
            Task { @MainActor in
                self?.updateToolTip()
            }
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }

        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            installOutsideClickMonitor()
        }
    }

    private func updateToolTip() {
        var lines = ["DockSwitch"]
        if let profile = state.profiles.first(where: { $0.id == state.activeProfileID }) {
            lines.append("Active: \(profile.name)")
            lines.append("Mic: \(profile.preferences.microphoneName ?? "System default")")
            lines.append("Speaker: \(profile.preferences.speakerName ?? "System default")")
            if let camera = profile.preferences.cameraName {
                lines.append("Camera: \(camera)")
            }
        } else {
            lines.append("No active profile")
        }
        statusItem.button?.toolTip = lines.joined(separator: "\n")
    }

    /// The app is an accessory (never the active app), so a `.transient`
    /// popover doesn't notice clicks that land in other applications. Watch
    /// for those globally while the popover is open and close it ourselves.
    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopoverFromOutsideClick()
            }
        }
    }

    private func closePopoverFromOutsideClick() {
        // Keep the popover (and any unsaved edits) if the profile editor
        // sheet is open on top of it.
        if popover.contentViewController?.view.window?.attachedSheet != nil {
            return
        }
        popover.performClose(nil)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit DockSwitch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        // Assign temporarily so the click opens the menu, then detach so
        // left-click keeps toggling the popover.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}

extension MenuBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
