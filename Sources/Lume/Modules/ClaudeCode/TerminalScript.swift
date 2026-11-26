import Foundation

enum TerminalScript {
    static let itermBundle = "com.googlecode.iterm2"

    static func focusITermSession(_ session: String) -> String {
        let id = session.replacingOccurrences(of: "\"", with: "")
        return """
        tell application id "\(itermBundle)"
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    repeat with aSession in sessions of aTab
                        if unique id of aSession is "\(id)" then
                            select aWindow
                            select aTab
                            select aSession
                            activate
                            return
                        end if
                    end repeat
                end repeat
            end repeat
            reopen
            activate
        end tell
        """
    }

    static func reopen(bundleID: String) -> String {
        let id = bundleID.replacingOccurrences(of: "\"", with: "")
        return """
        tell application id "\(id)"
            reopen
            activate
        end tell
        """
    }
}
