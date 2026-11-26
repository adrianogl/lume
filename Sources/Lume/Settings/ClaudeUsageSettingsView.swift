import SwiftUI

struct ClaudeUsageSettingsView: View {
    @ObservedObject var config: ConfigStore
    @State private var accounts: [ClaudeAccount] = []
    @State private var installed: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Toggle(SettingsText.usageEnabled, isOn: binding(\.modules.claudeUsage.enabled))
        } footer: {
            Text(SettingsText.usageFooter).frame(maxWidth: .infinity, alignment: .leading)
        }

        Group {
            Section {
                Toggle(SettingsText.usageClosed, isOn: binding(\.modules.claudeUsage.showWhenClosed))
                ForEach(UsageStatusLine.thresholdChoices, id: \.self) { value in
                    Toggle(SettingsText.percent(value), isOn: thresholdBinding(value))
                }
            } header: {
                Text(SettingsText.usageAlertsSection)
            } footer: {
                Text(SettingsText.usageAlertsFooter).frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                if accounts.isEmpty {
                    Text(SettingsText.claudeNoAccounts).foregroundStyle(.secondary)
                }
                ForEach(accounts) { account in
                    HStack(spacing: 10) {
                        Text(config.config.modules.claudeCode.accountNames[account.id] ?? account.defaultName)
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
                Text(SettingsText.usageAccountsSection)
            } footer: {
                Text(SettingsText.usageAccountsFooter).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disabled(!config.config.modules.claudeUsage.enabled)
        .onAppear(perform: reload)
    }

    private func reload() {
        accounts = ClaudeHookInstaller.accounts()
        installed = Set(accounts.filter(StatusLineInstaller.isInstalled(in:)).map(\.id))
    }

    private func change(_ account: ClaudeAccount, install: Bool) {
        do {
            if install {
                guard let executable = Bundle.main.executablePath else { return }
                try StatusLineInstaller.install(in: account, executable: executable)
            } else {
                try StatusLineInstaller.remove(from: account)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        reload()
    }

    private func thresholdBinding(_ value: Int) -> Binding<Bool> {
        Binding(
            get: { config.config.modules.claudeUsage.alertThresholds.contains(value) },
            set: { isOn in
                config.update { current in
                    var list = current.modules.claudeUsage.alertThresholds.filter { $0 != value }
                    if isOn { list.append(value) }
                    current.modules.claudeUsage.alertThresholds = list.sorted()
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
