import SwiftUI

enum CommandHook {
    static let command = "cmd-hook"
    static let notification = Notification.Name("local.lume.cmd-hook")
    static let shellThreshold = 10
    static let commandLimit = 300
    static let cleanupInterval: TimeInterval = 300
    static let staleAfter: TimeInterval = 7_200
    static let runningStaleAfter: TimeInterval = 6 * 3_600
    static let runningCheck: TimeInterval = 2
    static let cancelledExit = 130
    static let wrappers: Set<String> = ["sudo", "time", "nohup", "exec", "command", "noglob"]
    static let defaultIgnored = ["vim", "nvim", "vi", "nano", "less", "more", "man", "ssh", "top", "htop", "btop", "watch", "tail", "claude", "tmux", "fzf", "lazygit"]

    enum Flag {
        static let event = "--event"
        static let exit = "--exit"
        static let started = "--started"
        static let command = "--cmd"
        static let cwd = "--cwd"
        static let session = "--session"
    }

    enum Event {
        static let start = "start"
        static let end = "end"
    }

    enum Key {
        static let event = "event"
        static let exit = "exit"
        static let started = "started"
        static let command = "command"
        static let cwd = "cwd"
        static let session = "session"
        static let bundle = "bundle"
        static let terminalSession = "terminalSession"
    }
}

enum CommandShell {
    static let rcFile = ".zshrc"
    static let scriptDirectory = ".config/lume"
    static let scriptName = "lume.zsh"
    static let marker = "lume/lume.zsh"
    static let backupExtension = "lume-backup"
    static let rcLine = "[[ -r ~/.config/lume/lume.zsh ]] && source ~/.config/lume/lume.zsh"

    static func script(executable: String) -> String {
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return """
        zmodload zsh/datetime 2>/dev/null
        typeset -g _lume_bin=\(quoted)
        typeset -g _lume_min=\(CommandHook.shellThreshold)
        typeset -g _lume_cmd= _lume_start= _lume_timer=

        _lume_preexec() {
          _lume_cmd=$1
          _lume_start=$EPOCHSECONDS
          [[ -x $_lume_bin ]] || return
          ( sleep $_lume_min; "$_lume_bin" \(CommandHook.command) \(CommandHook.Flag.event) \(CommandHook.Event.start) \(CommandHook.Flag.started) $_lume_start \(CommandHook.Flag.command) "$1" \(CommandHook.Flag.cwd) "$PWD" \(CommandHook.Flag.session) "${ITERM_SESSION_ID:-$TTY}" ) &!
          _lume_timer=$!
        }

        _lume_precmd() {
          local code=$?
          [[ -n $_lume_start ]] || return 0
          [[ -n $_lume_timer ]] && kill $_lume_timer 2>/dev/null
          local started=$_lume_start
          _lume_start= _lume_timer=
          (( EPOCHSECONDS - started >= _lume_min )) || return 0
          [[ -x $_lume_bin ]] || return 0
          "$_lume_bin" \(CommandHook.command) \(CommandHook.Flag.event) \(CommandHook.Event.end) \(CommandHook.Flag.exit) $code \(CommandHook.Flag.started) $started \(CommandHook.Flag.command) "$_lume_cmd" \(CommandHook.Flag.cwd) "$PWD" \(CommandHook.Flag.session) "${ITERM_SESSION_ID:-$TTY}" &!
          return 0
        }

        typeset -ga preexec_functions precmd_functions
        preexec_functions=(${preexec_functions:#_lume_preexec} _lume_preexec)
        precmd_functions=(_lume_precmd ${precmd_functions:#_lume_precmd})

        """
    }
}

enum CommandLayout {
    static let symbol = "terminal"
    static let ok = Color(red: 48 / 255, green: 199 / 255, blue: 89 / 255)
    static let failed = Color(red: 1, green: 107 / 255, blue: 97 / 255)
    static let cancelled = Color.white
    static let failedRim = [
        Color(red: 1, green: 106 / 255, blue: 77 / 255),
        Color(red: 1, green: 69 / 255, blue: 58 / 255),
        Color(red: 1, green: 106 / 255, blue: 77 / 255),
        Color(red: 1, green: 69 / 255, blue: 58 / 255),
        Color(red: 1, green: 106 / 255, blue: 77 / 255)
    ]
    static let alertIconSize: CGFloat = 30
    static let alertGlyphSize: CGFloat = 13
    static let titleLength = 28
    static let spinnerSize: CGFloat = 9
    static let spinnerLine: CGFloat = 1.6
    static let spinnerPeriod: Double = 0.9
    static let runningFontSize: CGFloat = 10.5
    static let runningWidth: CGFloat = 44
    static let minuteChoices = [10, 30, 60, 300]
}

enum CommandCard {
    static let openSize = CGSize(width: 460, height: 200)
    static let refresh: TimeInterval = 15
    static let rowSpacing: CGFloat = 4
    static let rowHeight: CGFloat = 24
    static let listHeight: CGFloat = 132
    static let commandSize: CGFloat = 10.5
    static let textSize: CGFloat = 11
    static let dimAfter: TimeInterval = 1_800
}

enum CommandText {
    static let title = "Comandos"
    static let open = "Abrir"
    static let close = "Fechar"
    static let finished = "terminou"
    static let failed = "falhou"
    static let cancelled = "foi cancelado"
    static let okTag = "ok"
    static let cancelledTag = "ctrl-c"
    static let runningTag = "rodando"
    static let empty = "Nenhum comando demorado nas últimas 2 horas."
    static let runningLabel = "Comando rodando no terminal"

    static func exitTag(_ code: Int) -> String { "exit \(code)" }

    static func runningCount(_ count: Int) -> String {
        switch count {
        case 0: "Nada rodando"
        case 1: "1 rodando"
        default: "\(count) rodando"
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        if total < 60 { return "\(total) s" }
        let minutes = total / 60
        if minutes < 60 { return "\(minutes) min " + String(format: "%02d", total % 60) + " s" }
        return "\(minutes / 60) h " + String(format: "%02d", minutes % 60) + " min"
    }

    static func elapsed(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        if total < 3_600 { return "\(total / 60):" + String(format: "%02d", total % 60) }
        return "\(total / 3_600)h" + String(format: "%02d", (total % 3_600) / 60)
    }

    static func ago(from date: Date, to now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "agora" }
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h"
    }

    static func shortened(_ text: String, to length: Int) -> String {
        text.count > length ? String(text.prefix(length - 1)) + "…" : text
    }
}
