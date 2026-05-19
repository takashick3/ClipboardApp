import AppKit
import Foundation

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var isPasteInProgress = false

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setPasteInProgress(_ value: Bool) {
        isPasteInProgress = value
    }

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        if isPasteInProgress { return }

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        ClipboardStore.shared.add(text)
    }
}
