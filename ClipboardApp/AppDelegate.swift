import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popupWindow: NSWindow?
    private let monitor = ClipboardMonitor()
    private var globalShortcutMonitor: Any?
    private var localEventMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var selectedIndex: Int = 0
    private var selectedIndexBinding = SelectedIndexModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AccessibilityChecker.requestAccessibilityIfNeeded()
        setupStatusItem()
        monitor.start()
        setupGlobalShortcut()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        if let m = globalShortcutMonitor { NSEvent.removeMonitor(m) }
        if let m = localEventMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipboardApp")
            button.action = #selector(togglePopup)
            button.target = self
        }
    }

    @objc private func togglePopup() {
        if popupWindow?.isVisible == true {
            closePopup()
        } else {
            showPopup()
        }
    }

    // MARK: - Global Shortcut (⌘+Shift+V)

    private func setupGlobalShortcut() {
        globalShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 9 {
                DispatchQueue.main.async { self?.togglePopup() }
            }
        }
    }

    // MARK: - Popup

    private func showPopup() {
        previousApp = NSWorkspace.shared.frontmostApplication
        selectedIndexBinding.value = 0

        let store = ClipboardStore.shared
        let popupView = PopupView(
            store: store,
            selectedIndex: Binding(
                get: { [weak self] in self?.selectedIndexBinding.value ?? 0 },
                set: { [weak self] in self?.selectedIndexBinding.value = $0 }
            ),
            onSelect: { [weak self] item in self?.pasteItem(item) },
            onClose: { [weak self] in self?.closePopup() }
        )

        let hosting = NSHostingController(rootView: popupView)
        hosting.view.appearance = nil

        let window = PopupPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        window.isFloatingPanel = true
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentViewController = hosting

        window.setContentSize(hosting.view.fittingSize)
        positionWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        popupWindow = window
        setupLocalEventMonitor(store: store)
    }

    private func closePopup() {
        popupWindow?.close()
        popupWindow = nil
        if let m = localEventMonitor {
            NSEvent.removeMonitor(m)
            localEventMonitor = nil
        }
        previousApp?.activate(options: .activateIgnoringOtherApps)
        previousApp = nil
    }

    private func setupLocalEventMonitor(store: ClipboardStore) {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }

            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if event.window != self.popupWindow {
                    self.closePopup()
                }
                return event
            }

            // Keyboard handling
            switch event.keyCode {
            case 53: // Escape
                self.closePopup()
                return nil
            case 125: // Down arrow
                let max = store.items.count - 1
                if self.selectedIndexBinding.value < max {
                    self.selectedIndexBinding.value += 1
                }
                return nil
            case 126: // Up arrow
                if self.selectedIndexBinding.value > 0 {
                    self.selectedIndexBinding.value -= 1
                }
                return nil
            case 36, 76: // Return / Enter
                guard !store.items.isEmpty else { return nil }
                self.pasteItem(store.items[self.selectedIndexBinding.value])
                return nil
            default:
                return event
            }
        }
    }

    private func positionWindow(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let windowSize = window.frame.size
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main!
        let visibleFrame = screen.visibleFrame

        var x = mouseLocation.x
        var y = mouseLocation.y - windowSize.height - 10

        x = max(visibleFrame.minX + 4, min(x, visibleFrame.maxX - windowSize.width - 4))
        y = max(visibleFrame.minY + 4, min(y, visibleFrame.maxY - windowSize.height - 4))

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func pasteItem(_ item: ClipboardItem) {
        closePopup()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PasteService.shared.paste(text: item.text, monitor: self.monitor)
        }
    }
}

// MARK: - Helpers

class SelectedIndexModel: ObservableObject {
    @Published var value: Int = 0
}

class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
