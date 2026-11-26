import SwiftUI

struct SettingsView: View {
    @ObservedObject var config: ConfigStore
    @ObservedObject var week: WeekEventStore
    @State private var selection: NotchPage = .week
    @State private var icalText = ""
    @State private var chosenSourceKind: SourceKind?

    var body: some View {
        NavigationSplitView {
            List(NotchPage.allCases, id: \.self, selection: $selection) { page in
                Label {
                    HStack {
                        Text(page.title)
                        Spacer()
                        Circle()
                            .fill(isEnabled(page) ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                } icon: {
                    Image(systemName: page.symbol)
                }
            }
            .navigationSplitViewColumnWidth(SettingsLayout.sidebarWidth)
        } detail: {
            Form {
                switch selection {
                case .clock: clockSettings
                case .week: weekSettings
                }
                if let error = config.loadError {
                    Section {
                        Text(SettingsText.configError + " " + error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: SettingsLayout.size.width, minHeight: SettingsLayout.size.height)
        .onAppear { icalText = currentICalURL }
    }

    private var clockSettings: some View {
        Section {
            Toggle(SettingsText.clockEnabled, isOn: binding(\.modules.clock.enabled))
        } footer: {
            Text(SettingsText.clockFooter).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var weekSettings: some View {
        Section {
            Toggle(SettingsText.weekEnabled, isOn: binding(\.modules.week.enabled))
        } footer: {
            Text(SettingsText.weekFooter).frame(maxWidth: .infinity, alignment: .leading)
        }

        Group {
            Section(SettingsText.sourceSection) {
                Picker(SettingsText.sourceLabel, selection: sourceKind) {
                    Text(SettingsText.sourceEventKit).tag(SourceKind.eventKit)
                    Text(SettingsText.sourceICal).tag(SourceKind.ical)
                }
                .pickerStyle(.segmented)
                if sourceKind.wrappedValue == .ical {
                    TextField(SettingsText.icalLabel, text: $icalText, prompt: Text(SettingsText.icalPrompt))
                        .onSubmit(saveICal)
                    if savedSourceKind != .ical {
                        Text(SettingsText.icalPending).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }

            if sourceKind.wrappedValue == .eventKit {
                Section {
                    if week.availableCalendars.isEmpty {
                        Text(SettingsText.noCalendars).foregroundStyle(.secondary)
                    }
                    ForEach(week.availableCalendars) { choice in
                        Toggle(isOn: calendarBinding(choice.title)) {
                            HStack(spacing: 8) {
                                Circle().fill(choice.color).frame(width: 9, height: 9)
                                Text(choice.title)
                            }
                        }
                    }
                } header: {
                    Text(SettingsText.calendarsSection)
                } footer: {
                    Text(SettingsText.calendarsFooter).frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section(SettingsText.displaySection) {
                Picker(SettingsText.weekStartLabel, selection: binding(\.modules.week.weekStartsOn)) {
                    Text(SettingsText.monday).tag(WeekStart.monday)
                    Text(SettingsText.sunday).tag(WeekStart.sunday)
                }
                .pickerStyle(.segmented)
                Toggle(SettingsText.showWeekend, isOn: binding(\.modules.week.showWeekend))
            }
        }
        .disabled(!config.config.modules.week.enabled)
    }

    private func isEnabled(_ page: NotchPage) -> Bool {
        NotchPage.enabled(in: config.config).contains(page)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<LumeConfig, Value>) -> Binding<Value> {
        Binding(
            get: { config.config[keyPath: keyPath] },
            set: { value in config.update { $0[keyPath: keyPath] = value } }
        )
    }

    private enum SourceKind { case eventKit, ical }

    private var currentICalURL: String {
        if case .ical(let url) = config.config.modules.week.source { return url.absoluteString }
        return ""
    }

    private var savedSourceKind: SourceKind {
        if case .ical = config.config.modules.week.source { return .ical }
        return .eventKit
    }

    private var sourceKind: Binding<SourceKind> {
        Binding(
            get: { chosenSourceKind ?? savedSourceKind },
            set: { kind in
                chosenSourceKind = kind
                switch kind {
                case .eventKit: config.update { $0.modules.week.source = .eventKit }
                case .ical: saveICal()
                }
            }
        )
    }

    private func saveICal() {
        let text = icalText.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: text), let scheme = url.scheme, ["http", "https", "webcal"].contains(scheme) else { return }
        let fetchURL = scheme == "webcal" ? URL(string: "https" + text.dropFirst("webcal".count)) ?? url : url
        config.update { $0.modules.week.source = .ical(fetchURL) }
    }

    private func calendarBinding(_ title: String) -> Binding<Bool> {
        Binding(
            get: {
                let selected = config.config.modules.week.calendars
                return selected.isEmpty || selected.contains(title)
            },
            set: { isOn in
                config.update { current in
                    var selected = current.modules.week.calendars
                    if selected.isEmpty { selected = week.availableCalendars.map(\.title) }
                    if isOn {
                        if !selected.contains(title) { selected.append(title) }
                    } else {
                        selected.removeAll { $0 == title }
                    }
                    let all = Set(week.availableCalendars.map(\.title))
                    current.modules.week.calendars = Set(selected) == all ? [] : selected
                }
            }
        )
    }
}
