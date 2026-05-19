import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            CreditsTab()
                .tabItem {
                    Label("クレジット", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}

private struct CreditsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // アプリアイコン（実アイコン追加までプレースホルダー）
            Group {
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "doc.on.clipboard.fill")
                        .resizable()
                        .foregroundColor(.accentColor)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("ClipboardApp")
                .font(.title2)
                .fontWeight(.semibold)

            Text("© 2026 takashick")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
