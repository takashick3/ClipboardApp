import AppKit
import SwiftUI

class ToastWindowController {
    static let shared = ToastWindowController()

    private var window: NSWindow?
    private var dismissTimer: Timer?

    private init() {}

    /// トーストを表示する。メインスレッドから呼ぶこと。
    func show(message: String, systemIconName: String = "lock.fill") {
        dismissTimer?.invalidate()
        window?.close()
        window = nil

        let hosting = NSHostingController(
            rootView: ToastView(message: message, systemIconName: systemIconName)
        )
        hosting.view.appearance = nil

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentViewController = hosting
        panel.setContentSize(hosting.view.fittingSize)
        positionPanel(panel)

        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }

        window = panel
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.dismiss() }
        }
    }

    private func positionPanel(_ panel: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main!
        let sz = panel.frame.size
        let vf = screen.visibleFrame

        // カーソルの少し上に表示
        var x = mouse.x - sz.width / 2
        var y = mouse.y + 24
        x = max(vf.minX + 4, min(x, vf.maxX - sz.width - 4))
        y = min(y, vf.maxY - sz.height - 4)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func dismiss() {
        guard let w = window else { return }
        window = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            w.animator().alphaValue = 0
        }, completionHandler: {
            w.close()
        })
    }
}
