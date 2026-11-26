import SwiftUI

struct ClaudeCodeSettingsView: View {
    @ObservedObject var config: ConfigStore
    @State private var accounts: [ClaudeAccount] = []
    @State private var installed: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Toggle(SettingsText.claudeEnabled, isOn: binding(\.modules.claudeCode.enabled))
        } footer: {
            Text(SettingsText.claudeFooter).frame(maxWidth: .infinity, alignment: .leading)
        }

        Group {
            Section(SettingsText.claudeEventsSection) {
                Toggle(SettingsText.claudePermission, isOn: binding(\.modules.claudeCode.permission))
                Toggle(SettingsText.claudeWaiting, isOn: binding(\.modules.claudeCode.waiting))
                Toggle(SettingsText.claudeFinished, isOn: binding(\.modules.claudeCode.finished))
            }

            Section {
                if accounts.isEmpty {
                    Text(SettingsText.claudeNoAccounts).foregroundStyle(.secondary)
                }
                ForEach(accounts) { account in
                    HStack(spacing: 10) {
                        TextField(account.directory.lastPathComponent, text: nameBinding(account), prompt: Text(account.defaultName))
                            .frame(maxWidth: 140)
                        Text("~/" + account.directory.lastPathComponent)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if installed.contains(account.id) {
                            Text(SettingsText.claudeInstalled).font(.callout).foregroundStyle(.green)
                            Button(SettingsText.claudeRemove) { change(account, install: false) }
                        } else {
                            Button(SettingsText.claudeInstall) { change(account, install: true) }
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).font(.callout).foregroundStyle(.red)
                }
            } header: {
                Text(SettingsText.claudeAccountsSection)
            } footer: {
                Text(SettingsText.claudeAccountsFooter).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disabled(!config.config.modules.claudeCode.enabled)
        .onAppear(perform: reload)
    }

    private func reload() {
        accounts = ClaudeHookInstaller.accounts()
        installed = Set(accounts.filter(ClaudeHookInstaller.isInstalled(in:)).map(\.id))
    }

    private func change(_ account: ClaudeAccount, install: Bool) {
        do {
            if install {
                guard let executable = Bundle.main.executablePath else { return }
                try ClaudeHookInstaller.install(in: account, executable: executable)
            } else {
                try ClaudeHookInstaller.remove(from: account)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        reload()
    }

    private func nameBinding(_ account: ClaudeAccount) -> Binding<String> {
        Binding(
            get: { config.config.modules.claudeCode.accountNames[account.id] ?? "" },
            set: { name in
                config.update { current in
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    current.modules.claudeCode.accountNames[account.id] = trimmed.isEmpty ? nil : trimmed
                }
            }
        )
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<LumeConfig, Value>) -> Binding<Value> {
        Binding(
            get: { config.config[keyPath: keyPath] },
            set: { value in config.update { $0[keyPath: keyPath] = value } }
        )
    }
}
