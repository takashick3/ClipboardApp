import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("一般", systemImage: "gearshape")
                }
            CreditsTab()
                .tabItem {
                    Label("クレジット", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 340)
        .padding()
    }
}

// MARK: - 一般タブ

private struct GeneralTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Picker("保存する履歴数", selection: $settings.maxHistoryCount) {
                ForEach(AppSettings.historyOptions, id: \.self) { count in
                    Text("\(count)件").tag(count)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 280)

            Picker("ウィンドウ幅", selection: $settings.popupWidth) {
                ForEach(AppSettings.widthOptions, id: \.self) { w in
                    Text("\(Int(w)) px").tag(w)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 280)

            Picker("最大ウィンドウ高さ", selection: $settings.popupMaxHeightRatio) {
                ForEach(AppSettings.heightRatioOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 280)

            Picker("文字サイズ", selection: $settings.fontSizeScale) {
                ForEach(FontSizeScale.allCases, id: \.self) { scale in
                    Text(scale.label).tag(scale)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Toggle("ログイン時に自動起動", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))
        }
        .padding(.vertical, 12)
    }
}

// MARK: - クレジットタブ

private struct CreditsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

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

            Text("Ver1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("© 2026 takashick")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
