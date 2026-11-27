import SwiftUI

struct CommandSettingsView: View {
    @ObservedObject var config: ConfigStore
    @State private var isInstalled = false
    @State private var errorMessage: String?
    @State private var ignoredText = ""

    var body: some View {
        Section {
            Toggle(SettingsText.commandsEnabled, isOn: binding(\.modules.commands.enabled))
        } footer: {
            Text(SettingsText.commandsFooter).frame(maxWidth: .infinity, alignment: .leading)
        }

        Group {
            Section {
                HStack {
                    Text(SettingsText.commandsShellLabel)
                    Spacer()
                    if isInstalled {
                        Text(SettingsText.claudeInstalled).font(.callout).foregroundStyle(.green)
                        Button(SettingsText.claudeRemove) { change(install: false) }
                    } else {
                        Button(SettingsText.commandsInstall) { change(install: true) }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).font(.callout).foregroundStyle(.red)
                }
            } header: {
                Text(SettingsText.commandsShellSection)
            } footer: {
                Text(SettingsText.commandsShellFooter).frame(maxWidth: .infinity, alignment: .leading)
            }

            Section(SettingsText.commandsWhenSection) {
                Picker(SettingsText.commandsMinimum, selection: binding(\.modules.commands.minSeconds)) {
                    ForEach(CommandLayout.minuteChoices, id: \.self) { seconds in
                        Text(SettingsText.seconds(seconds)).tag(seconds)
                    }
                }
                Picker(SettingsText.commandsNotify, selection: binding(\.modules.commands.notify)) {
                    Text(SettingsText.commandsNotifyAway).tag(CommandNotifyMode.away)
                    Text(SettingsText.commandsNotifyAlways).tag(CommandNotifyMode.always)
                    Text(SettingsText.commandsNotifyFailures).tag(CommandNotifyMode.failures)
                }
                Toggle(SettingsText.commandsCancelled, isOn: binding(\.modules.commands.cancelled))
                Toggle(SettingsText.commandsRunning, isOn: binding(\.modules.commands.showRunning))
            }

            Section {
                TextField(SettingsText.commandsIgnoredLabel, text: $ignoredText)
                    .onSubmit(saveIgnored)
            } header: {
                Text(SettingsText.commandsIgnoredSection)
            } footer: {
                Text(SettingsText.commandsIgnoredFooter).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disabled(!config.config.modules.commands.enabled)
        .onAppear {
            isInstalled = CommandShellInstaller.isInstalled()
            ignoredText = config.config.modules.commands.ignored.joined(separator: ", ")
        }
        .onDisappear(perform: saveIgnored)
    }

    private func change(install: Bool) {
        do {
            if install {
                guard let executable = Bundle.main.executablePath else { return }
                try CommandShellInstaller.install(executable: executable)
            } else {
                try CommandShellInstaller.remove()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isInstalled = CommandShellInstaller.isInstalled()
    }

    private func saveIgnored() {
        let list = ignoredText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard list != config.config.modules.commands.ignored else { return }
        config.update { $0.modules.commands.ignored = list }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<LumeConfig, Value>) -> Binding<Value> {
        Binding(
            get: { config.config[keyPath: keyPath] },
            set: { value in config.update { $0[keyPath: keyPath] = value } }
        )
    }
}
