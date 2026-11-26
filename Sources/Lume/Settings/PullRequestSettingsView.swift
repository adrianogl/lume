import SwiftUI

struct PullRequestSettingsView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var monitor: PullRequestMonitor
    @State private var scopeText = ""

    var body: some View {
        Section {
            Toggle(SettingsText.prEnabled, isOn: binding(\.modules.pullRequests.enabled))
            if config.config.modules.pullRequests.enabled {
                HStack {
                    Text(status).font(.callout).foregroundStyle(statusColor)
                    Spacer()
                    Button(SettingsText.prRefresh, action: monitor.refresh)
                }
            }
        } footer: {
            Text(SettingsText.prFooter).frame(maxWidth: .infinity, alignment: .leading)
        }

        Group {
            Section(SettingsText.prAlertsSection) {
                Toggle(SettingsText.prReviewRequested, isOn: binding(\.modules.pullRequests.alerts.reviewRequested))
                Toggle(SettingsText.prCIFailed, isOn: binding(\.modules.pullRequests.alerts.ciFailed))
                Toggle(SettingsText.prChangesRequested, isOn: binding(\.modules.pullRequests.alerts.changesRequested))
                Toggle(SettingsText.prApproved, isOn: binding(\.modules.pullRequests.alerts.approved))
            }

            Section {
                Toggle(SettingsText.prDrafts, isOn: binding(\.modules.pullRequests.includeDrafts))
                Toggle(SettingsText.prBots, isOn: binding(\.modules.pullRequests.includeBots))
                TextField(SettingsText.prScope, text: $scopeText, prompt: Text(SettingsText.prScopePrompt))
                    .onSubmit(saveScope)
                Picker(SettingsText.prPoll, selection: binding(\.modules.pullRequests.pollMinutes)) {
                    ForEach(PRPolling.choices, id: \.self) { minutes in
                        Text(SettingsText.pollMinutes(minutes)).tag(minutes)
                    }
                }
            } header: {
                Text(SettingsText.prFilterSection)
            } footer: {
                Text(SettingsText.prScopeFooter).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disabled(!config.config.modules.pullRequests.enabled)
        .onAppear { scopeText = config.config.modules.pullRequests.organizations.joined(separator: ", ") }
    }

    private var status: String {
        switch monitor.loadState {
        case .idle, .loading: SettingsText.prLoading
        case .missingCLI: PRText.missingCLI
        case .notLoggedIn: PRText.notLoggedIn
        case .failed(let error): PRText.failedPrefix + error
        case .ready: SettingsText.prConnected(monitor.login)
        }
    }

    private var statusColor: Color {
        switch monitor.loadState {
        case .ready: .green
        case .idle, .loading: .secondary
        default: .red
        }
    }

    private func saveScope() {
        let list = scopeText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        config.update { $0.modules.pullRequests.organizations = list }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<LumeConfig, Value>) -> Binding<Value> {
        Binding(
            get: { config.config[keyPath: keyPath] },
            set: { value in config.update { $0[keyPath: keyPath] = value } }
        )
    }
}
