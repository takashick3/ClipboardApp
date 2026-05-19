import AppKit
import CoreGraphics

class PasteService {
    static let shared = PasteService()

    private init() {}

    func paste(text: String, monitor: ClipboardMonitor) {
        let previousText = NSPasteboard.general.string(forType: .string)

        monitor.setPasteInProgress(true)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.sendCmdV()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                monitor.setPasteInProgress(false)
                if let prev = previousText {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(prev, forType: .string)
                }
            }
        }
    }

    private func sendCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09

        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
