import SwiftUI
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("一般", systemImage: "gearshape")
                }
            SnippetSettingsTab()
                .tabItem {
                    Label("スニペット", systemImage: "doc.text")
                }
            CreditsTab()
                .tabItem {
                    Label("クレジット", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

// MARK: - 一般タブ

private struct GeneralTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                settingRow("保存する履歴数") {
                    Picker("", selection: $settings.maxHistoryCount) {
                        ForEach(AppSettings.historyOptions, id: \.self) { count in
                            Text("\(count)件").tag(count)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 150)
                }

                settingRow("ウィンドウ幅") {
                    Picker("", selection: $settings.popupWidth) {
                        ForEach(AppSettings.widthOptions, id: \.self) { w in
                            Text("\(Int(w)) px").tag(w)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 150)
                }

                settingRow("最大ウィンドウ高さ") {
                    Picker("", selection: $settings.popupMaxHeightRatio) {
                        ForEach(AppSettings.heightRatioOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 150)
                }

                settingRow("文字サイズ") {
                    Picker("", selection: $settings.fontSizeScale) {
                        ForEach(FontSizeScale.allCases, id: \.self) { scale in
                            Text(scale.label).tag(scale)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200)
                }

                settingRow("ログイン時に自動起動") {
                    Button(action: { settings.setLaunchAtLogin(!settings.launchAtLogin) }) {
                        Image(systemName: settings.launchAtLogin ? "checkmark.square.fill" : "square")
                            .foregroundColor(settings.launchAtLogin ? .accentColor : Color(NSColor.tertiaryLabelColor))
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("すべての履歴を削除する", systemImage: "trash")
            }
            .confirmationDialog("すべての履歴を削除しますか？", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    ClipboardStore.shared.clear()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は元に戻せません。")
            }


        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    // ラベル幅を 200pt 固定にすることで全行のコントロール左端を数学的に一致させる
    private func settingRow<C: View>(_ label: String, @ViewBuilder control: () -> C) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 200, alignment: .trailing)
            control()
            Spacer()
        }
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

            Text(AppConstants.versionLabel)
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
