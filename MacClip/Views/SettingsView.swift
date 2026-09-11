import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("maxHistorySize") private var maxHistorySize: Int = 100
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = (SMAppService.mainApp.status == .enabled)
                        }
                    }
            }

            Section("History") {
                Stepper("Max history size: \(maxHistorySize)", value: $maxHistorySize, in: 10...500, step: 10)
                    .help("Pinned entries are never pruned.")
            }

            Section("Keyboard Shortcut") {
                LabeledContent("Show history") {
                    Text("⌘ ⌃ V")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Section("Permissions") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Auto-paste uses AppleScript to send ⌘V after you select an entry.")
                        .font(.callout)
                    Text("The first time you paste, macOS will ask: MacClip wants to control System Events. Click OK -- that one-time grant persists across restarts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .padding(.vertical, 8)
    }
}
