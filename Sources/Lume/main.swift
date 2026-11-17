import AppKit

let arguments = CommandLine.arguments
if arguments.count > 1, arguments[1] == ClaudeHookConfig.command {
    ClaudeHookBridge.post(Array(arguments.dropFirst(2)))
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
