import AppKit
import SwiftUI
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popupWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let monitor = ClipboardMonitor()
    private var eventTap: CFMachPort?
    private var localEventMonitor: Any?
    private var globalClickMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var selectedIndex: Int = 0
    private var selectedIndexBinding = SelectedIndexModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AccessibilityChecker.requestAccessibilityIfNeeded()
        setupStatusItem()
        monitor.start()
        setupEventTap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        tearDownEventTap()
        if let m = localEventMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let icon = NSImage(named: "menubar_iconTemplate")
            icon?.isTemplate = true
            button.image = icon
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

    // MARK: - CGEventTap (⌘+Shift+V を消費してトグル)

    private func setupEventTap() {
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                return delegate.handleCGEvent(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func tearDownEventTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        eventTap = nil
    }

    private func handleCGEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isCmd   = flags.contains(.maskCommand)
        let isShift = flags.contains(.maskShift)
        let isV     = keyCode == 9

        // ⌘+Shift+V: 消費してポップアップトグル
        if isCmd && isShift && isV {
            DispatchQueue.main.async { self.togglePopup() }
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    // MARK: - Popup

    private func showPopup() {
        previousApp = NSWorkspace.shared.frontmostApplication
        selectedIndexBinding.value = 0

        let store = ClipboardStore.shared
        let popupView = PopupView(
            store: store,
            selectionModel: selectedIndexBinding,
            onSelect: { [weak self] item in self?.pasteItem(item) },
            onClose: { [weak self] in self?.closePopup() },
            onOpenSettings: { [weak self] in
                self?.closePopup()
                self?.openSettings()
            }
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
        setupGlobalClickMonitor()
    }

    private func closePopup() {
        popupWindow?.close()
        popupWindow = nil
        if let m = localEventMonitor {
            NSEvent.removeMonitor(m)
            localEventMonitor = nil
        }
        if let m = globalClickMonitor {
            NSEvent.removeMonitor(m)
            globalClickMonitor = nil
        }
        previousApp?.activate(options: .activateIgnoringOtherApps)
        previousApp = nil
    }

    private func setupGlobalClickMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.closePopup() }
        }
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
                // ⌘付きキーはすべて消費してポップアップ外への流出を防ぐ
                if event.modifierFlags.contains(.command) {
                    return nil
                }
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

    // MARK: - Settings Window

    func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "設定"
        window.styleMask = NSWindow.StyleMask([.titled, .closable])
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}

// MARK: - Helpers

class SelectedIndexModel: ObservableObject {
    @Published var value: Int = 0
}

class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
