import AppKit

@MainActor
final class ClaudeHookBridge {
    private let model: NotchModel
    private var observer: NSObjectProtocol?

    init(model: NotchModel) {
        self.model = model
    }

    nonisolated static func post(_ values: [String]) {
        guard values.count >= 3 else { return }
        var info = [
            ClaudeHookConfig.kindKey: values[0],
            ClaudeHookConfig.titleKey: values[1],
            ClaudeHookConfig.messageKey: values[2]
        ]
        if values.count > 3, !values[3].isEmpty {
            info[ClaudeHookConfig.bundleKey] = values[3]
        }
        DistributedNotificationCenter.default().postNotificationName(
            ClaudeHookConfig.notificationName,
            object: nil,
            userInfo: info,
            deliverImmediately: true
        )
    }

    func start() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: ClaudeHookConfig.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let info = note.userInfo as? [String: String] ?? [:]
            MainActor.assumeIsolated { self?.present(info) }
        }
    }

    private func present(_ info: [String: String]) {
        guard let title = info[ClaudeHookConfig.titleKey] else { return }
        let appURL = info[ClaudeHookConfig.bundleKey].flatMap {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
        model.present(NotchAlert(
            kind: info[ClaudeHookConfig.kindKey] == ClaudeHookConfig.attentionKind ? .attention : .success,
            title: title,
            subtitle: info[ClaudeHookConfig.messageKey] ?? "",
            actionTitle: appURL == nil ? nil : ClaudeHookConfig.actionTitle,
            actionURL: appURL
        ))
    }
}
