import AppKit
import SwiftUI
import CoreGraphics
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popupWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let monitor = ClipboardMonitor()
    private var eventTap: CFMachPort?
    private var localEventMonitor: Any?
    private var globalClickMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var popupState = PopupStateModel()
    private var tabChangeCancellable: AnyCancellable?

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
            let icon = NSImage(systemSymbolName: "list.bullet.clipboard", accessibilityDescription: "ClipboardApp")
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
            showPopup(tab: .history)
        }
    }

    // MARK: - CGEventTap (⌘+Shift+V / ⌘+Shift+B を消費してトグル)

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

        if isCmd && isShift {
            if keyCode == 9 { // V
                DispatchQueue.main.async { self.handleShortcut(tab: .history) }
                return nil
            }
            if keyCode == 11 { // B
                DispatchQueue.main.async { self.handleShortcut(tab: .snippets) }
                return nil
            }
        }
        return Unmanaged.passRetained(event)
    }

    private func handleShortcut(tab: PopupTab) {
        if popupWindow?.isVisible == true {
            if popupState.activeTab == tab {
                closePopup()
            } else {
                popupState.activeTab = tab
                popupState.selectedIndex = 0
                popupState.selectedSnippetFolder = nil
            }
        } else {
            showPopup(tab: tab)
        }
    }

    // MARK: - Popup

    private func showPopup(tab: PopupTab) {
        previousApp = NSWorkspace.shared.frontmostApplication
        popupState.activeTab = tab
        popupState.selectedIndex = 0
        popupState.selectedSnippetFolder = nil

        let clipboardStore = ClipboardStore.shared
        let snippetStore = SnippetStore.shared
        let pinnedStore = PinnedStore.shared
        let popupView = PopupView(
            clipboardStore: clipboardStore,
            snippetStore: snippetStore,
            pinnedStore: pinnedStore,
            state: popupState,
            onSelect: { [weak self] item in self?.pasteItem(item) },
            onSelectSnippet: { [weak self] text in self?.pasteSnippet(text) },
            onClose: { [weak self] in self?.confirmQuit() },
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
        setupLocalEventMonitor(clipboardStore: clipboardStore, snippetStore: snippetStore)
        setupGlobalClickMonitor()
        setupTabChangeObserver(window: window, hosting: hosting)
    }

    private func closePopup() {
        tabChangeCancellable = nil
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

    private func setupTabChangeObserver(window: NSWindow, hosting: NSHostingController<PopupView>) {
        tabChangeCancellable = popupState.$activeTab
            .dropFirst()
            .sink { [weak window, weak hosting] _ in
                DispatchQueue.main.async {
                    guard let window = window, let hosting = hosting else { return }
                    let oldFrame = window.frame
                    let newSize = hosting.view.fittingSize
                    // 上辺を固定したまま高さだけ変える
                    let newOriginY = oldFrame.maxY - newSize.height
                    window.setFrame(NSRect(x: oldFrame.minX, y: newOriginY, width: newSize.width, height: newSize.height), display: true, animate: false)
                }
            }
    }

    private func setupGlobalClickMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.closePopup() }
        }
    }

    private func setupLocalEventMonitor(clipboardStore: ClipboardStore, snippetStore: SnippetStore) {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }

            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if event.window != self.popupWindow {
                    self.closePopup()
                }
                return event
            }

            switch event.keyCode {
            case 53: // Escape
                if self.popupState.activeTab == .snippets && self.popupState.selectedSnippetFolder != nil {
                    self.popupState.selectedSnippetFolder = nil
                    self.popupState.selectedIndex = 0
                } else {
                    self.closePopup()
                }
                return nil
            case 125: // Down arrow
                self.moveSelectionDown(clipboardStore: clipboardStore, snippetStore: snippetStore)
                return nil
            case 126: // Up arrow
                self.moveSelectionUp(snippetStore: snippetStore)
                return nil
            case 36, 76: // Return / Enter
                self.handleEnter(clipboardStore: clipboardStore, snippetStore: snippetStore)
                return nil
            default:
                if event.modifierFlags.contains(.command) {
                    return nil
                }
                return event
            }
        }
    }

    private func moveSelectionDown(clipboardStore: ClipboardStore, snippetStore: SnippetStore) {
        let maxIndex: Int
        if popupState.activeTab == .history {
            maxIndex = Array(clipboardStore.items.prefix(AppSettings.shared.maxHistoryCount)).count - 1
        } else if let folder = popupState.selectedSnippetFolder {
            maxIndex = folder.snippets.count - 1
        } else {
            maxIndex = snippetStore.folders.count - 1
        }
        if popupState.selectedIndex < maxIndex {
            popupState.selectedIndex += 1
        }
    }

    private func moveSelectionUp(snippetStore: SnippetStore) {
        if popupState.activeTab == .history {
            let minIndex = -PinnedStore.shared.items.count
            if popupState.selectedIndex > minIndex {
                popupState.selectedIndex -= 1
            }
        } else {
            let minIndex: Int = popupState.selectedSnippetFolder != nil ? -1 : 0
            if popupState.selectedIndex > minIndex {
                popupState.selectedIndex -= 1
            }
        }
    }

    private func handleEnter(clipboardStore: ClipboardStore, snippetStore: SnippetStore) {
        if popupState.activeTab == .history {
            if popupState.selectedIndex < 0 {
                // ピン済みアイテム: selectedIndex -1 → items[count-1], -count → items[0]
                let pinnedItems = PinnedStore.shared.items
                let idx = pinnedItems.count + popupState.selectedIndex
                guard idx >= 0 && idx < pinnedItems.count else { return }
                pasteSnippet(pinnedItems[idx].text)
                return
            }
            let displayItems = Array(clipboardStore.items.prefix(AppSettings.shared.maxHistoryCount))
            guard !displayItems.isEmpty else { return }
            pasteItem(displayItems[popupState.selectedIndex])
        } else if let folder = popupState.selectedSnippetFolder {
            if popupState.selectedIndex == -1 {
                // Back
                popupState.selectedSnippetFolder = nil
                popupState.selectedIndex = snippetStore.folders.firstIndex(where: { $0.id == folder.id }) ?? 0
            } else if popupState.selectedIndex < folder.snippets.count {
                pasteSnippet(folder.snippets[popupState.selectedIndex].content)
            }
        } else {
            guard !snippetStore.folders.isEmpty else { return }
            popupState.selectedSnippetFolder = snippetStore.folders[popupState.selectedIndex]
            popupState.selectedIndex = 0
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

    private func pasteSnippet(_ text: String) {
        closePopup()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PasteService.shared.paste(text: text, monitor: self.monitor)
        }
    }

    // MARK: - Quit

    private func confirmQuit() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "ClipboardApp を終了しますか？"
        alert.informativeText = "終了するとクリップボード履歴の監視が停止します。"
        alert.addButton(withTitle: "終了")
        alert.addButton(withTitle: "キャンセル")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
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

class PopupStateModel: ObservableObject {
    @Published var activeTab: PopupTab = .history
    @Published var selectedIndex: Int = 0
    @Published var selectedSnippetFolder: SnippetFolder? = nil
}

class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
